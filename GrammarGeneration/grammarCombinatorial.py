import random

variables = {} #  variable name : variable value 

def giveExp(depth): 
    if depth <= 2: 
        return giveLitExp()
    else: 
        choice = random.randint(0,1)
        if choice == 0: # roll again
            return giveBinExp(depth - 1) 
        if choice == 1: 
            return  giveUnaExp(depth - 1) 
        
        
def giveBinExp(depth):
    return giveExp(depth) + "+" + giveExp(depth) 

def giveUnaExp(depth):
    return  "-" +  giveExp(depth)

def giveLitExp(): 
    return "1" 

def giveVarDecl():
    variableName = "x" + str(len(variables))
    variables[variableName] = random.randint(0,100) # random value 
    return " Int " + variableName + "=" + str(variables[variableName]) + ";"

def givePrint(): 
    if len(variables) > 0: 
        choice = random.randint(0, len(variables)-1)
        variableName = list(variables.keys())[choice] 
        res = "printf('Variable: %s, " + variableName + ");" 
        return  res 
    else: 
        res = "printf('no variables');" 
        return  res

def giveStatement():
    choice = random.randint(0,1) 
    if choice == 0: 
        return giveVarDecl()
    else: 
        return givePrint()
    
def giveProgram(): 
    lines = ["#include <stdio.h>", "int main(){"]
    for i in range(3): 
        lines.append(giveStatement())
    lines.append("}")
    res = "\n".join(lines)
    return res 

print(giveProgram())

print(giveExp(5))