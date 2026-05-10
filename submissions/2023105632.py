
def add(x, y): return x + y
def subtract(x, y): return x - y
def multiply(x, y): return x * y
def divide(x, y):
    if y == 0: return "0으로 나눌 수 없습니다."
    return x / y

print("--- 계산기 프로그램 ---")
num1 = float(input("첫 번째 숫자: "))
num2 = float(input("두 번째 숫자: "))
op = input("연산자 (+, -, *, /): ")

if op == '+': print(f"결과: {add(num1, num2)}")
elif op == '-': print(f"결과: {subtract(num1, num2)}")
elif op == '*': print(f"결과: {multiply(num1, num2)}")
elif op == '/': print(f"결과: {divide(num1, num2)}")
else: print("잘못된 연산자입니다.")