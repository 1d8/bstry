# Bstry - Nimlang Wiper Malware

This malware will:
* cycle through all files in a user's /home/ directory & add them to a list
* cycle through that list & grab the number of lines of each file, then generate a random number between 1 & the number of lines in each file. That random number will be used to encrypt x amount of lines in the file
  * EX: Say a file has 36 lines. We generate a random number between 1 & 36 and we get 24. We will be encrypting the first 24 lines of that file.
* The encryption key used is a combination of 3 things:
  1. The first line of the file to be encrypted
  2. The current working directory from which the malware is ran
  3. The current user's username

The encryption algorithm used is xxtea.

This malware was coded to work only on Linux machines as of now

Todo:
1. Input error handling.

# Compilation

`nim compile <filename>`

# VT-Scan

![](https://i.imgur.com/w2carx1.png)

[Hybrid Analysis Link](https://www.hybrid-analysis.com/sample/3af6ec0e13bf8c3702768c5104c238218047c22f6de42332f926892baff3e65a?environmentId=300)
