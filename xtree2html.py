#!/usr/bin/python3
import sys

def countstars(string):
    count = 0
    for char in string:
        if char == "*":
            count += 1
        else:
            break
    return count

lines = sys.stdin.readlines()
laststars=0
currentline=0
out='<ul id="myUL">'

while(currentline < len(lines)):
    stars=countstars(lines[currentline])
    
    levels = laststars - stars
    while (levels > 0):
        out += '\n'
        out += "  " * (stars + 1)
        out += "</ul>"
        levels -=1
    if (levels < 0):
        out += "  " * stars
        out += '<ul class="nested">'

    out += '\n'
    out += "  " * stars
    out += '<li>'
    if currentline+1 < len(lines) and countstars(lines[currentline+1]) > stars:
        out += '<span class="caret">'
        spanning=True;
    else:
        spanning=False;
        
    out += lines[currentline].strip().lstrip("*")
    if spanning:
        out += "</span>\n"
    laststars=stars
    currentline+=1

out += "\n  </ul>"
out += "\n</ul>"

with open("precode.txt", "r") as file:
    print(file.read())

print(out)

with open("postcode.txt", "r") as file:
    print(file.read())

