def checkMultipleOfThree(a):
    return(a%3 == 0)

def calcQuotientAndRemain(b):
    l =[]
    l.append(b//3)
    l.append(b%3)
    return l

def calcCumulativeValue(c,d):
    sum = 0
    for num in range(0,d):
        if 1 <= num < d:
            if num % c == 0:
                sum = sum + num
    return sum

def calcCumulativeList(e,f):
    sumlist = []
    for ele in range(0,f):
        if 1<= ele < f:
            if ele % e == 0:
                sumlist.append(ele)
    return sumlist

def calcCumulativeValueAndList(g,h):
    finallist = []
    sum = 0
    for num in range(0,h):
        if 1 <= num < h:
            if num % g == 0:
                sum = sum + num
    sumlist = []
    for ele in range(0,h):
        if 1<= ele < h:
            if ele % g == 0:
                sumlist.append(ele)
    finallist.append(sum)
    finallist.append(sumlist)
    return finallist
