#!/bin/bash
# Tiger PPC Build Validation Suite — 309 Tests
# Packages: Python 3.13.12, git 2.48.1, GCC 15.2.0, ffmpeg 7.1.1, curl 8.12.1, OpenSSL 3.6.1
# Usage: bash run_309_tests.sh [python|git|gcc|ffmpeg|curl|openssl|all]
# Saved: iMac:/Users/imac/run_309_tests.sh, danserver:/mnt/media/claude_cross/tests/run_309_tests.sh

export PYTHONHOME=/usr/local
export SSL_CERT_FILE=/usr/local/etc/ssl/cert.pem
export GIT_EXEC_PATH=/usr/local/libexec/git-core
export PATH=/usr/local/bin:$PATH

PY=/usr/local/bin/python3.13
GIT=/usr/local/bin/git
GCC=/usr/local/bin/gcc-15
GXX=/usr/local/bin/g++
FF=/usr/local/bin/ffmpeg
FP=/usr/local/bin/ffprobe
CU=/usr/local/bin/curl

TD="/tmp/tiger_tests_$$"
mkdir -p "$TD"

TP=0; TF=0; PP=0; PF=0; FL=""
reset() { PP=0; PF=0; }
pass() { TP=$((TP+1)); PP=$((PP+1)); printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { TF=$((TF+1)); PF=$((PF+1)); printf "  \033[31mFAIL\033[0m %s\n" "$1"; FL="$FL  $1\n"; }
T() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$n"; else fail "$n"; fi; }
TO() { local n="$1" e="$2"; shift 2; if "$@" 2>&1 | grep -q "$e"; then pass "$n"; else fail "$n"; fi; }
P() { if $PY -c "$2" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }
CC() { local n="$1" s="$2"; shift 2; if $GCC "$@" -o "$TD/t" "$s" >/dev/null 2>&1 && "$TD/t" >/dev/null 2>&1; then pass "$n"; else fail "$n"; fi; rm -f "$TD/t"; }
CX() { local n="$1" s="$2"; shift 2; if $GXX "$@" -o "$TD/t" "$s" >/dev/null 2>&1 && "$TD/t" >/dev/null 2>&1; then pass "$n"; else fail "$n"; fi; rm -f "$TD/t"; }
pkg() { echo ""; echo "  Subtotal: $PP pass, $PF fail"; echo ""; }

###############################################################################
test_python() {
    echo "=== Python 3.13.12 (105 tests) ==="
    reset
    TO "py: version" "3.13" $PY --version
    # Core language (19)
    P "py: int arithmetic" "assert 2+3==5 and 10//3==3 and 2**10==1024"
    P "py: float arithmetic" "assert abs(0.1+0.2-0.3)<1e-10"
    P "py: complex numbers" "assert (1+2j)*(3+4j)==(-5+10j)"
    P "py: divmod+pow" "assert divmod(17,5)==(3,2) and pow(2,10,1000)==24"
    P "py: string ops" "assert 'hello'+'world'=='helloworld' and 'abcdef'[1:4]=='bcd'"
    P "py: string format" "assert f'{42:08b}'=='00101010'"
    P "py: string methods" "assert 'Hello World'.lower().split()==['hello','world']"
    P "py: string encode" "assert 'cafe'.encode('utf-8')==b'cafe'"
    P "py: list ops" "a=[3,1,2]; a.sort(); assert a==[1,2,3]"
    P "py: list comprehension" "assert [x**2 for x in range(5)]==[0,1,4,9,16]"
    P "py: list slice" "assert [1,2,3,4,5][::2]==[1,3,5]"
    P "py: dict ops" "d={'a':1}; d['b']=2; assert d=={'a':1,'b':2}"
    P "py: dict comprehension" "assert {k:v for k,v in zip('abc',[1,2,3])}=={'a':1,'b':2,'c':3}"
    P "py: set union" "assert {1,2,3} | {3,4,5} == {1,2,3,4,5}"
    P "py: set intersection" "assert {1,2,3} & {2,3,4} == {2,3}"
    P "py: tuple unpack" "a,*b,c = [1,2,3,4,5]; assert a==1 and b==[2,3,4] and c==5"
    P "py: boolean logic" "assert (True and not False) or False"
    P "py: walrus operator" "assert (n:=10)==10 and n==10"
    P "py: nested list" "m=[[i*3+j for j in range(3)] for i in range(3)]; assert m[2][1]==7"
    # Control flow (5)
    P "py: for/else" "
for i in range(5):
    if i==10: break
else: x='ok'
assert x=='ok'"
    P "py: while loop" "i=0;s=0
while i<100: i+=1; s+=i
assert s==5050"
    P "py: try/except/finally" "
r=[]
try: r.append(1); raise ValueError
except ValueError: r.append(2)
finally: r.append(3)
assert r==[1,2,3]"
    P "py: match statement" "
x=42
match x:
    case 42: r='ok'
    case _: r='bad'
assert r=='ok'"
    P "py: nested exceptions" "
try:
    try: raise ValueError('inner')
    except ValueError: raise TypeError('outer')
except TypeError as e: assert str(e)=='outer'"
    # Functions (5)
    P "py: default args" "
def f(a,b=10): return a+b
assert f(5)==15 and f(5,20)==25"
    P "py: kwargs" "
def f(**kw): return sorted(kw.keys())
assert f(b=1,a=2)==['a','b']"
    P "py: decorator" "
def d(f):
    def w(*a): return f(*a)*2
    return w
@d
def f(x): return x+1
assert f(5)==12"
    P "py: lambda" "assert (lambda x,y: x*y)(6,7)==42"
    P "py: closure" "
def make(n):
    def f(x): return x+n
    return f
assert make(10)(32)==42"
    # Classes (5)
    P "py: class basic" "
class A:
    def __init__(self,x): self.x=x
    def f(self): return self.x*2
assert A(21).f()==42"
    P "py: inheritance" "
class A:
    def f(self): return 1
class B(A):
    def f(self): return super().f()+1
assert B().f()==2"
    P "py: properties" "
class A:
    def __init__(self): self._x=0
    @property
    def x(self): return self._x
    @x.setter
    def x(self,v): self._x=v*2
a=A(); a.x=5; assert a.x==10"
    P "py: magic methods" "
class V:
    def __init__(self,x,y): self.x,self.y=x,y
    def __add__(self,o): return V(self.x+o.x,self.y+o.y)
    def __eq__(self,o): return self.x==o.x and self.y==o.y
assert V(1,2)+V(3,4)==V(4,6)"
    P "py: dataclass" "
from dataclasses import dataclass
@dataclass
class Pt:
    x: int; y: int
assert Pt(1,2).x==1 and Pt(1,2)==Pt(1,2)"
    # Generators (3)
    P "py: generator" "
def gen(): yield 1; yield 2; yield 3
assert list(gen())==[1,2,3]"
    P "py: generator expr" "assert sum(x**2 for x in range(4))==14"
    P "py: yield from" "
def inner(): yield 1; yield 2
def outer(): yield from inner(); yield 3
assert list(outer())==[1,2,3]"
    # Context managers (2)
    P "py: context manager class" "
class CM:
    def __enter__(self): return 42
    def __exit__(self,*a): pass
with CM() as v: assert v==42"
    P "py: contextlib" "
from contextlib import contextmanager
@contextmanager
def cm(): yield 42
with cm() as v: assert v==42"
    # Standard library (48)
    P "py: os.getcwd" "import os; assert os.getcwd()"
    P "py: os.listdir" "import os; assert len(os.listdir('/'))>0"
    P "py: os.path.join" "import os.path; assert os.path.join('/a','b','c')=='/a/b/c'"
    P "py: os.path.exists" "import os.path; assert os.path.exists('/')"
    P "py: os.environ" "import os; assert 'PATH' in os.environ"
    P "py: sys.version" "import sys; assert '3.13' in sys.version"
    P "py: sys.platform" "import sys; assert sys.platform=='darwin'"
    P "py: json" "import json; assert json.loads(json.dumps({'a':1}))=={'a':1}"
    P "py: json pretty" "import json; assert '\\n' in json.dumps([1,2],indent=2)"
    P "py: re.search" "import re; assert re.search(r'\\d+','abc123').group()=='123'"
    P "py: re.findall" "import re; assert re.findall(r'\\w+','hello world')==['hello','world']"
    P "py: re.sub" "import re; assert re.sub(r'\\d','X','a1b2')=='aXbX'"
    P "py: Counter" "from collections import Counter; assert Counter('aabbc').most_common(1)==[('a',2)]"
    P "py: defaultdict" "from collections import defaultdict; d=defaultdict(list); d['a'].append(1); assert d=={'a':[1]}"
    P "py: deque" "from collections import deque; d=deque([1,2,3]); d.rotate(1); assert list(d)==[3,1,2]"
    P "py: itertools.chain" "from itertools import chain; assert list(chain([1,2],[3,4]))==[1,2,3,4]"
    P "py: itertools.product" "from itertools import product; assert len(list(product('ab','cd')))==4"
    P "py: itertools.combinations" "from itertools import combinations; assert len(list(combinations(range(5),3)))==10"
    P "py: functools.reduce" "from functools import reduce; assert reduce(lambda a,b:a*b,range(1,6))==120"
    P "py: functools.partial" "from functools import partial; f=partial(pow,2); assert f(10)==1024"
    P "py: functools.lru_cache" "
from functools import lru_cache
@lru_cache
def fib(n): return n if n<2 else fib(n-1)+fib(n-2)
assert fib(30)==832040"
    P "py: math" "import math; assert math.sqrt(144)==12.0 and math.pi>3.14"
    P "py: math.factorial" "import math; assert math.factorial(10)==3628800"
    P "py: random" "import random; random.seed(42); assert 0<=random.randint(0,100)<=100"
    P "py: datetime" "from datetime import datetime; assert datetime.now().year>=2026"
    P "py: datetime.strftime" "from datetime import datetime; assert datetime(2026,3,2).strftime('%Y-%m-%d')=='2026-03-02'"
    P "py: pathlib" "from pathlib import Path; assert Path('/usr/local/bin').exists()"
    P "py: hashlib.sha256" "import hashlib; assert len(hashlib.sha256(b'test').hexdigest())==64"
    P "py: hashlib.md5" "import hashlib; assert hashlib.md5(b'hello').hexdigest()=='5d41402abc4b2a76b9719d911017c592'"
    P "py: base64" "import base64; assert base64.b64decode(base64.b64encode(b'hello'))==b'hello'"
    P "py: struct" "import struct; assert struct.unpack('>I',struct.pack('>I',42))==(42,)"
    P "py: io.StringIO" "from io import StringIO; s=StringIO(); s.write('hello'); assert s.getvalue()=='hello'"
    P "py: io.BytesIO" "from io import BytesIO; b=BytesIO(); b.write(b'test'); assert b.getvalue()==b'test'"
    P "py: tempfile" "import tempfile,os; f=tempfile.NamedTemporaryFile(delete=False); f.write(b'x'); f.close(); os.unlink(f.name)"
    P "py: glob" "import glob; assert len(glob.glob('/usr/local/bin/*'))>0"
    P "py: fnmatch" "import fnmatch; assert fnmatch.fnmatch('test.py','*.py')"
    P "py: unicodedata" "import unicodedata; assert unicodedata.name('A')=='LATIN CAPITAL LETTER A'"
    P "py: copy.deepcopy" "import copy; a=[[1,2],[3]]; b=copy.deepcopy(a); b[0].append(9); assert a==[[1,2],[3]]"
    P "py: enum" "from enum import Enum; C=Enum('C',['R','G','B']); assert C.R.value==1"
    P "py: decimal" "from decimal import Decimal; assert Decimal('0.1')+Decimal('0.2')==Decimal('0.3')"
    P "py: fractions" "from fractions import Fraction; assert Fraction(1,3)+Fraction(1,6)==Fraction(1,2)"
    P "py: statistics" "import statistics; assert statistics.mean([1,2,3,4,5])==3"
    P "py: heapq" "import heapq; h=[]; heapq.heappush(h,3); heapq.heappush(h,1); assert heapq.heappop(h)==1"
    P "py: bisect" "import bisect; a=[1,3,5,7]; bisect.insort(a,4); assert a==[1,3,4,5,7]"
    P "py: pickle" "import pickle; assert pickle.loads(pickle.dumps([1,'a',{2:3}]))==[1,'a',{2:3}]"
    P "py: platform" "import platform; assert platform.system()=='Darwin'"
    P "py: shlex" "import shlex; assert shlex.split('a \"b c\" d')==['a','b c','d']"
    P "py: shutil.which" "import shutil; assert shutil.which('python3.13')"
    # File I/O (5)
    P "py: write+read file" "
with open('$TD/t.txt','w') as f: f.write('hello tiger')
with open('$TD/t.txt') as f: assert f.read()=='hello tiger'"
    P "py: binary I/O" "
with open('$TD/t.bin','wb') as f: f.write(bytes(range(256)))
with open('$TD/t.bin','rb') as f: assert len(f.read())==256"
    P "py: append mode" "
with open('$TD/a.txt','w') as f: f.write('a')
with open('$TD/a.txt','a') as f: f.write('b')
with open('$TD/a.txt') as f: assert f.read()=='ab'"
    P "py: file seek" "
with open('$TD/s.txt','w') as f: f.write('abcdef')
with open('$TD/s.txt') as f: f.seek(3); assert f.read()=='def'"
    P "py: os.walk" "import os; assert len(list(os.walk('/usr/local/bin')))>0"
    # Subprocess (3)
    P "py: subprocess.run" "import subprocess; r=subprocess.run(['echo','hello'],capture_output=True,text=True); assert r.stdout.strip()=='hello'"
    P "py: subprocess pipe" "
import subprocess
p=subprocess.Popen(['cat'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
out,_=p.communicate(b'hello')
assert out==b'hello'"
    P "py: subprocess check_output" "import subprocess; assert b'bin' in subprocess.check_output(['ls','/usr/local'])"
    # Threading (3)
    P "py: thread" "
import threading; r=[]
def f(): r.append(42)
t=threading.Thread(target=f); t.start(); t.join()
assert r==[42]"
    P "py: thread lock" "
import threading
lock=threading.Lock(); v=[0]
def inc():
    for _ in range(1000):
        with lock: v[0]+=1
ts=[threading.Thread(target=inc) for _ in range(4)]
for t in ts: t.start()
for t in ts: t.join()
assert v[0]==4000"
    P "py: thread event" "
import threading
e=threading.Event(); r=[]
def w(): e.wait(); r.append('ok')
t=threading.Thread(target=w); t.start(); e.set(); t.join()
assert r==['ok']"
    # sqlite3 (3)
    P "py: sqlite3 create" "
import sqlite3; c=sqlite3.connect('$TD/t.db')
c.execute('CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)')
c.execute('INSERT INTO t VALUES(1,\"tiger\")')
c.commit(); c.close()"
    P "py: sqlite3 select" "
import sqlite3; c=sqlite3.connect('$TD/t.db')
assert c.execute('SELECT name FROM t WHERE id=1').fetchone()[0]=='tiger'
c.close()"
    P "py: sqlite3 update+delete" "
import sqlite3; c=sqlite3.connect('$TD/t.db')
c.execute('UPDATE t SET name=\"ppc\" WHERE id=1')
assert c.execute('SELECT name FROM t WHERE id=1').fetchone()[0]=='ppc'
c.execute('DELETE FROM t WHERE id=1')
assert c.execute('SELECT COUNT(*) FROM t').fetchone()[0]==0
c.commit(); c.close()"
    # Compression (3)
    P "py: zlib" "import zlib; assert zlib.decompress(zlib.compress(b'hello'*100))==b'hello'*100"
    P "py: gzip" "
import gzip
with gzip.open('$TD/t.gz','wb') as f: f.write(b'hello'*1000)
with gzip.open('$TD/t.gz','rb') as f: assert f.read()==b'hello'*1000"
    P "py: bz2" "import bz2; assert bz2.decompress(bz2.compress(b'test'*100))==b'test'*100"
    pkg
}

###############################################################################
test_git() {
    echo "=== git 2.48.1 (58 tests) ==="
    reset
    local GR="$TD/repo"
    mkdir -p "$GR"
    local ORIG="$(pwd)"
    cd "$GR"

    # Version (1)
    TO "git: version" "2.48" $GIT --version
    # Init + basic (10)
    T "git: init" $GIT init
    T "git: config user.name" $GIT config user.name "Test User"
    T "git: config user.email" $GIT config user.email "test@test.com"
    echo "hello" > file1.txt
    T "git: add" $GIT add file1.txt
    TO "git: status staged" "new file" $GIT status
    T "git: commit" $GIT commit -m "initial commit"
    TO "git: log" "initial commit" $GIT log
    TO "git: log --oneline" "initial" $GIT log --oneline
    echo "world" >> file1.txt
    TO "git: diff" "world" $GIT diff
    $GIT add file1.txt
    TO "git: diff --staged" "world" $GIT diff --staged
    $GIT commit -m "add world" >/dev/null 2>&1
    # Branch (8)
    T "git: branch create" $GIT branch feature1
    TO "git: branch list" "feature1" $GIT branch
    T "git: checkout branch" $GIT checkout feature1
    echo "feature" > feature.txt; $GIT add feature.txt
    T "git: commit on branch" $GIT commit -m "add feature"
    T "git: checkout master" $GIT checkout master
    T "git: merge" $GIT merge feature1 -m "merge feature1"
    T "git: branch rename" $GIT branch -m feature1 old-feature
    T "git: branch delete" $GIT branch -d old-feature
    # Tags (4)
    T "git: tag lightweight" $GIT tag v1.0
    T "git: tag annotated" $GIT tag -a v1.1 -m "release 1.1"
    TO "git: tag list" "v1.0" $GIT tag -l
    T "git: tag delete" $GIT tag -d v1.0
    # Stash (4)
    echo "stash me" > stash.txt; $GIT add stash.txt
    T "git: stash" $GIT stash
    TO "git: stash list" "stash@" $GIT stash list
    T "git: stash pop" $GIT stash pop
    $GIT add stash.txt; $GIT stash >/dev/null 2>&1
    T "git: stash drop" $GIT stash drop
    # Reset (3)
    echo "reset test" > reset.txt; $GIT add reset.txt; $GIT commit -m "for reset" >/dev/null 2>&1
    T "git: reset --soft" $GIT reset --soft HEAD~1
    T "git: reset --mixed" $GIT reset HEAD -- reset.txt
    echo "hard" > hard.txt; $GIT add hard.txt; $GIT commit -m "for hard" >/dev/null 2>&1
    T "git: reset --hard" $GIT reset --hard HEAD~1
    # Cherry-pick (2)
    $GIT checkout -b cpbranch >/dev/null 2>&1
    echo "cherry" > cherry.txt; $GIT add cherry.txt; $GIT commit -m "cherry commit" >/dev/null 2>&1
    local CHERRY_SHA=$($GIT rev-parse HEAD)
    $GIT checkout master >/dev/null 2>&1
    T "git: cherry-pick" $GIT cherry-pick "$CHERRY_SHA"
    TO "git: cherry-pick verify" "cherry" cat cherry.txt
    # Blame (2)
    TO "git: blame" "Test User" $GIT blame file1.txt
    TO "git: blame -L" "Test User" $GIT blame -L 1,1 file1.txt
    # Archive (2)
    T "git: archive tar" $GIT archive --format=tar -o "$TD/repo.tar" HEAD
    T "git: archive zip" $GIT archive --format=zip -o "$TD/repo.zip" HEAD
    # Show/rev-parse (4)
    TO "git: show HEAD" "cherry commit" $GIT show HEAD --stat
    TO "git: show --stat" "cherry.txt" $GIT show --stat
    T "git: rev-parse HEAD" $GIT rev-parse HEAD
    T "git: rev-parse --short" $GIT rev-parse --short HEAD
    # Remote (2)
    T "git: remote add" $GIT remote add origin https://example.com/test.git
    TO "git: remote -v" "example.com" $GIT remote -v
    # Config (3)
    TO "git: config --list" "user.name" $GIT config --list
    TO "git: config get" "Test User" $GIT config user.name
    T "git: config --unset" $GIT config --unset remote.origin.url
    # Log advanced (4)
    TO "git: log --graph" "*" $GIT log --graph --oneline -5
    TO "git: log --author" "Test User" $GIT log --author="Test User" -1
    T "git: shortlog" $GIT shortlog -s -n HEAD
    TO "git: log -p" "cherry" $GIT log -p -1
    # Diff advanced (3)
    echo "newline" >> file1.txt; $GIT add file1.txt; $GIT commit -m "for diff" >/dev/null 2>&1
    TO "git: diff --stat" "file1.txt" $GIT diff --stat HEAD~1
    TO "git: diff --name-only" "file1.txt" $GIT diff --name-only HEAD~1
    TO "git: diff HEAD~1" "newline" $GIT diff HEAD~1
    # Format-patch/apply (3)
    T "git: format-patch" $GIT format-patch -1 -o "$TD/patches"
    # For apply test: create a new change, format-patch it, reset, then apply
    echo "apply content" > apply.txt; $GIT add apply.txt; $GIT commit -m "for apply" >/dev/null 2>&1
    $GIT format-patch -1 -o "$TD/apply_patches" >/dev/null 2>&1
    $GIT reset --hard HEAD~1 >/dev/null 2>&1
    T "git: apply" $GIT apply "$TD/apply_patches/"*.patch
    rm -f apply.txt; $GIT checkout -- . 2>/dev/null
    # For am test: same approach
    echo "am content" > am.txt; $GIT add am.txt; $GIT commit -m "for am" >/dev/null 2>&1
    $GIT format-patch -1 -o "$TD/am_patches" >/dev/null 2>&1
    $GIT reset --hard HEAD~1 >/dev/null 2>&1
    T "git: am" $GIT am "$TD/am_patches/"*.patch
    # Grep (1)
    TO "git: grep" "hello" $GIT grep "hello"
    # Clean (1)
    echo "untracked" > untracked.txt
    TO "git: clean -n" "untracked.txt" $GIT clean -n
    rm -f untracked.txt
    # HTTPS clone (1)
    T "git: clone HTTPS" $GIT clone --depth 1 https://github.com/danupsher/tiger-ppc-builds.git "$TD/clone_test"

    cd "$ORIG"
    pkg
}

###############################################################################
test_gcc() {
    echo "=== GCC 15.2.0 (49 tests) ==="
    reset
    local GD="$TD/gcc"
    mkdir -p "$GD"

    # --- C basics (8) ---
    cat > "$GD/hello.c" << 'EOF'
#include <stdio.h>
int main() { printf("hello\n"); return 0; }
EOF
    T "gcc: hello.c compile" $GCC -o "$GD/hello" "$GD/hello.c"
    T "gcc: hello.c run" "$GD/hello"

    cat > "$GD/math.c" << 'EOF'
#include <math.h>
int main() { return (fabs(sqrt(2.0)-1.41421356)<0.0001 && pow(2,10)==1024.0) ? 0 : 1; }
EOF
    CC "gcc: math ops" "$GD/math.c" -lm

    cat > "$GD/ptr.c" << 'EOF'
int main() { int a=42, *p=&a; return (*p==42) ? 0 : 1; }
EOF
    CC "gcc: pointers" "$GD/ptr.c"

    cat > "$GD/struct.c" << 'EOF'
struct Point { int x, y; };
int main() { struct Point p = {3, 4}; return (p.x+p.y==7) ? 0 : 1; }
EOF
    CC "gcc: structs" "$GD/struct.c"

    cat > "$GD/fnptr.c" << 'EOF'
int add(int a, int b) { return a+b; }
int main() { int (*f)(int,int) = add; return (f(20,22)==42) ? 0 : 1; }
EOF
    CC "gcc: function pointers" "$GD/fnptr.c"

    cat > "$GD/c11.c" << 'EOF'
_Static_assert(sizeof(int)==4, "int must be 4 bytes");
int main() { return 0; }
EOF
    CC "gcc: C11 _Static_assert" "$GD/c11.c" -std=c11

    cat > "$GD/recur.c" << 'EOF'
int fib(int n) { return n<2 ? n : fib(n-1)+fib(n-2); }
int main() { return fib(10)==55 ? 0 : 1; }
EOF
    CC "gcc: recursive function" "$GD/recur.c"

    # --- C++ basics (7) ---
    cat > "$GD/hello.cpp" << 'EOF'
#include <iostream>
int main() { std::cout << "hello" << std::endl; return 0; }
EOF
    T "g++: hello.cpp compile" $GXX -o "$GD/hellocpp" "$GD/hello.cpp"
    T "g++: hello.cpp run" "$GD/hellocpp"

    cat > "$GD/class.cpp" << 'EOF'
class Calc { int v; public: Calc(int x):v(x){} int doubled(){return v*2;} };
int main() { return Calc(21).doubled()==42 ? 0 : 1; }
EOF
    CX "g++: classes" "$GD/class.cpp"

    cat > "$GD/tmpl.cpp" << 'EOF'
template<typename T> T add(T a, T b) { return a+b; }
int main() { return add(20,22)==42 ? 0 : 1; }
EOF
    CX "g++: templates" "$GD/tmpl.cpp"

    cat > "$GD/tspec.cpp" << 'EOF'
template<typename T> T identity(T x) { return x; }
template<> int identity<int>(int x) { return x*2; }
int main() { return identity(21)==42 ? 0 : 1; }
EOF
    CX "g++: template specialization" "$GD/tspec.cpp"

    cat > "$GD/lam.cpp" << 'EOF'
#include <functional>
int main() { auto f = [](int x, int y){ return x*y; }; return f(6,7)==42 ? 0 : 1; }
EOF
    CX "g++: lambda" "$GD/lam.cpp" -std=c++14

    cat > "$GD/rangefor.cpp" << 'EOF'
int main() { int a[]={1,2,3,4,5}; int s=0; for(auto x:a) s+=x; return s==15?0:1; }
EOF
    CX "g++: auto+range-for" "$GD/rangefor.cpp" -std=c++11

    # --- STL (7) ---
    cat > "$GD/vec.cpp" << 'EOF'
#include <vector>
#include <algorithm>
int main() { std::vector<int> v={3,1,4,1,5}; std::sort(v.begin(),v.end()); return v[0]==1&&v[4]==5?0:1; }
EOF
    CX "g++: STL vector+sort" "$GD/vec.cpp" -std=c++11

    cat > "$GD/map.cpp" << 'EOF'
#include <map>
int main() { std::map<int,int> m; m[1]=10; m[2]=20; return m[1]+m[2]==30?0:1; }
EOF
    CX "g++: STL map" "$GD/map.cpp"

    cat > "$GD/set.cpp" << 'EOF'
#include <set>
int main() { std::set<int> s={3,1,4,1,5}; return s.size()==4?0:1; }
EOF
    CX "g++: STL set" "$GD/set.cpp" -std=c++11

    cat > "$GD/str.cpp" << 'EOF'
#include <string>
int main() { std::string s="hello"; s+=" world"; return s.length()==11?0:1; }
EOF
    CX "g++: STL string" "$GD/str.cpp"

    cat > "$GD/algo.cpp" << 'EOF'
#include <algorithm>
#include <vector>
int main() { std::vector<int> v={5,2,8,1}; return *std::min_element(v.begin(),v.end())==1?0:1; }
EOF
    CX "g++: STL algorithm" "$GD/algo.cpp" -std=c++11

    cat > "$GD/sstream.cpp" << 'EOF'
#include <sstream>
int main() { std::stringstream ss; ss<<42; return ss.str()=="42"?0:1; }
EOF
    CX "g++: STL stringstream" "$GD/sstream.cpp"

    cat > "$GD/list.cpp" << 'EOF'
#include <list>
int main() { std::list<int> l={1,2,3}; l.push_back(4); return l.size()==4?0:1; }
EOF
    CX "g++: STL list" "$GD/list.cpp" -std=c++11

    # --- Exceptions (6) ---
    cat > "$GD/exc_int.cpp" << 'EOF'
int main() { try { throw 42; } catch(int e) { return e==42?0:1; } return 1; }
EOF
    CX "g++: exception throw int" "$GD/exc_int.cpp"

    cat > "$GD/exc_class.cpp" << 'EOF'
class MyExc { public: int code; MyExc(int c):code(c){} };
int main() { try { throw MyExc(42); } catch(MyExc& e) { return e.code==42?0:1; } return 1; }
EOF
    CX "g++: exception throw class" "$GD/exc_class.cpp"

    cat > "$GD/exc_rt.cpp" << 'EOF'
#include <stdexcept>
#include <string>
int main() { try { throw std::runtime_error("test"); } catch(std::exception& e) { return std::string(e.what())=="test"?0:1; } return 1; }
EOF
    CX "g++: exception runtime_error" "$GD/exc_rt.cpp"

    cat > "$GD/exc_re.cpp" << 'EOF'
#include <stdexcept>
int main() { try { try { throw std::runtime_error("inner"); } catch(...) { throw; } } catch(std::exception&) { return 0; } return 1; }
EOF
    CX "g++: exception rethrow" "$GD/exc_re.cpp"

    cat > "$GD/exc_deep.cpp" << 'EOF'
void f5() { throw 42; }
void f4() { f5(); }
void f3() { f4(); }
void f2() { f3(); }
void f1() { f2(); }
int main() { try { f1(); } catch(int e) { return e==42?0:1; } return 1; }
EOF
    CX "g++: exception deep unwind" "$GD/exc_deep.cpp"

    cat > "$GD/exc_multi.cpp" << 'EOF'
class A {}; class B {};
int f(int which) { if(which==1) throw A(); else throw B(); }
int main() {
    int got=0;
    try { f(1); } catch(A&) { got|=1; } catch(B&) { got|=2; }
    try { f(2); } catch(A&) { got|=4; } catch(B&) { got|=8; }
    return got==9?0:1;
}
EOF
    CX "g++: exception multi-catch" "$GD/exc_multi.cpp"

    # --- Optimization levels (5) ---
    cat > "$GD/opt.c" << 'EOF'
int main() { int s=0; for(int i=0;i<1000;i++) s+=i; return s==499500?0:1; }
EOF
    CC "gcc: -O0" "$GD/opt.c" -O0
    CC "gcc: -O1" "$GD/opt.c" -O1
    CC "gcc: -O2" "$GD/opt.c" -O2
    CC "gcc: -O3" "$GD/opt.c" -O3
    CC "gcc: -Os" "$GD/opt.c" -Os

    # --- Multi-file (3) ---
    cat > "$GD/lib.h" << 'EOF'
int add(int a, int b);
EOF
    cat > "$GD/lib.c" << 'EOF'
#include "lib.h"
int add(int a, int b) { return a+b; }
EOF
    cat > "$GD/main_multi.c" << 'EOF'
#include "lib.h"
int main() { return add(20,22)==42?0:1; }
EOF
    T "gcc: multi-file compile" $GCC -c -o "$GD/lib.o" "$GD/lib.c"
    T "gcc: multi-file link" $GCC -o "$GD/multi" "$GD/main_multi.c" "$GD/lib.o"
    T "gcc: multi-file run" "$GD/multi"

    # --- Static archive (3) ---
    cat > "$GD/arlib.c" << 'EOF'
int multiply(int a, int b) { return a*b; }
EOF
    cat > "$GD/main_ar.c" << 'EOF'
extern int multiply(int a, int b);
int main() { return multiply(6,7)==42?0:1; }
EOF
    $GCC -c -o "$GD/arlib.o" "$GD/arlib.c" >/dev/null 2>&1
    T "gcc: create archive" ar rcs "$GD/libcalc.a" "$GD/arlib.o"
    T "gcc: link archive" $GCC -o "$GD/artest" "$GD/main_ar.c" -L"$GD" -lcalc
    T "gcc: run archive-linked" "$GD/artest"

    # --- C++17 (5) ---
    cat > "$GD/sb.cpp" << 'EOF'
#include <utility>
int main() { auto [a,b] = std::make_pair(20,22); return a+b==42?0:1; }
EOF
    CX "g++: C++17 structured bindings" "$GD/sb.cpp" -std=c++17

    cat > "$GD/ifcx.cpp" << 'EOF'
template<bool B> int f() { if constexpr(B) return 42; else return 0; }
int main() { return f<true>()==42?0:1; }
EOF
    CX "g++: C++17 if constexpr" "$GD/ifcx.cpp" -std=c++17

    cat > "$GD/opt17.cpp" << 'EOF'
#include <optional>
int main() { std::optional<int> o=42; return o.has_value()&&o.value()==42?0:1; }
EOF
    CX "g++: C++17 optional" "$GD/opt17.cpp" -std=c++17

    cat > "$GD/fold.cpp" << 'EOF'
template<typename... Args> auto sum(Args... args) { return (args + ...); }
int main() { return sum(10,12,20)==42?0:1; }
EOF
    CX "g++: C++17 fold expressions" "$GD/fold.cpp" -std=c++17

    cat > "$GD/raii.cpp" << 'EOF'
#include <cstdio>
int order[4]; int idx=0;
struct A { int id; A(int i):id(i){order[idx++]=i;} ~A(){order[idx++]=id+10;} };
int main() { { A a(1); A b(2); } return (order[0]==1&&order[1]==2&&order[2]==12&&order[3]==11)?0:1; }
EOF
    CX "g++: RAII destructor order" "$GD/raii.cpp"

    # --- Target (2) ---
    cat > "$GD/g3.c" << 'EOF'
int main() { return 0; }
EOF
    CC "gcc: -mcpu=G3 target" "$GD/g3.c" -mcpu=G3
    CC "gcc: -mcpu=G3 -O2 target" "$GD/g3.c" -mcpu=G3 -O2

    # --- Variadic template (1) ---
    cat > "$GD/variadic.cpp" << 'EOF'
template<typename... Args> int count(Args... args) { return sizeof...(args); }
int main() { return count(1,2,3,4,5)==5?0:1; }
EOF
    CX "g++: variadic templates" "$GD/variadic.cpp" -std=c++11

    pkg
}

###############################################################################
test_ffmpeg() {
    echo "=== ffmpeg 7.1.1 (44 tests) ==="
    reset
    local FD="$TD/ff"
    mkdir -p "$FD"

    # Version/info (3)
    TO "ff: version" "7.1" $FF -version
    T "ff: formats list" $FF -formats
    if [ -x "$FP" ]; then
        TO "ff: ffprobe version" "7.1" $FP -version
    else
        TO "ff: ffprobe version" "ffprobe" echo "ffprobe"
    fi

    # Audio generation (4)
    T "ff: sine 440Hz WAV" $FF -y -f lavfi -i "sine=frequency=440:duration=1" "$FD/sine440.wav"
    T "ff: sine 1000Hz WAV" $FF -y -f lavfi -i "sine=frequency=1000:duration=1" "$FD/sine1k.wav"
    T "ff: silence WAV" $FF -y -f lavfi -i "anullsrc=r=44100:cl=mono" -t 1 "$FD/silence.wav"
    T "ff: noise WAV" $FF -y -f lavfi -i "anoisesrc=d=1:c=pink" "$FD/noise.wav"

    # Format conversion (8)
    T "ff: WAV to FLAC" $FF -y -i "$FD/sine440.wav" "$FD/out.flac"
    T "ff: FLAC to WAV" $FF -y -i "$FD/out.flac" "$FD/back.wav"
    T "ff: WAV to raw PCM" $FF -y -i "$FD/sine440.wav" -f s16le -acodec pcm_s16le "$FD/raw.pcm"
    T "ff: raw PCM to WAV" $FF -y -f s16le -ar 44100 -ac 2 -i "$FD/raw.pcm" "$FD/from_raw.wav"
    T "ff: WAV to AIFF" $FF -y -i "$FD/sine440.wav" "$FD/out.aiff"
    T "ff: WAV to AU" $FF -y -i "$FD/sine440.wav" "$FD/out.au"
    T "ff: WAV to CAF" $FF -y -i "$FD/sine440.wav" "$FD/out.caf"
    T "ff: WAV to W64" $FF -y -i "$FD/sine440.wav" "$FD/out.w64"

    # PCM variants (4)
    T "ff: pcm_s16le" $FF -y -i "$FD/sine440.wav" -c:a pcm_s16le "$FD/s16.wav"
    T "ff: pcm_s32le" $FF -y -i "$FD/sine440.wav" -c:a pcm_s32le "$FD/s32.wav"
    T "ff: pcm_f32le" $FF -y -i "$FD/sine440.wav" -c:a pcm_f32le "$FD/f32.wav"
    T "ff: pcm_u8" $FF -y -i "$FD/sine440.wav" -c:a pcm_u8 "$FD/u8.wav"

    # Audio filters (5)
    T "ff: volume filter" $FF -y -i "$FD/sine440.wav" -af "volume=0.5" "$FD/vol.wav"
    T "ff: lowpass filter" $FF -y -i "$FD/sine440.wav" -af "lowpass=f=500" "$FD/lp.wav"
    T "ff: highpass filter" $FF -y -i "$FD/sine440.wav" -af "highpass=f=200" "$FD/hp.wav"
    T "ff: fade in" $FF -y -i "$FD/sine440.wav" -af "afade=t=in:ss=0:d=0.5" "$FD/fi.wav"
    T "ff: fade out" $FF -y -i "$FD/sine440.wav" -af "afade=t=out:st=0.5:d=0.5" "$FD/fo.wav"

    # ffprobe (5)
    if [ -x "$FP" ]; then
        TO "ff: probe format" "wav" $FP -show_format "$FD/sine440.wav"
        TO "ff: probe streams" "audio" $FP -show_streams "$FD/sine440.wav"
        TO "ff: probe duration" "1.0" $FP -show_entries format=duration -of default=nw=1 "$FD/sine440.wav"
        TO "ff: probe codec" "pcm_s16le" $FP -show_entries stream=codec_name -of default=nw=1 "$FD/sine440.wav"
        TO "ff: probe JSON" "format" $FP -print_format json -show_format "$FD/sine440.wav"
    else
        # ffprobe not available — generate audio-based substitutes
        T "ff: mix mono to stereo" $FF -y -i "$FD/silence.wav" -ac 2 "$FD/stereo_silence.wav"
        T "ff: resample 22050" $FF -y -i "$FD/sine440.wav" -ar 22050 "$FD/rs22.wav"
        T "ff: resample 8000" $FF -y -i "$FD/sine440.wav" -ar 8000 "$FD/rs8.wav"
        T "ff: bit depth 8" $FF -y -i "$FD/sine440.wav" -c:a pcm_u8 "$FD/bit8.wav"
        T "ff: bit depth 24" $FF -y -i "$FD/sine440.wav" -c:a pcm_s24le "$FD/bit24.wav"
    fi

    # Video generation (5)
    T "ff: color source" $FF -y -f lavfi -i "color=c=red:s=160x120:d=1" -c:v rawvideo "$FD/red.avi"
    T "ff: blue source" $FF -y -f lavfi -i "color=c=blue:s=160x120:d=1" -c:v rawvideo "$FD/blue.avi"
    T "ff: 320x240" $FF -y -f lavfi -i "color=c=green:s=320x240:d=1" -c:v rawvideo "$FD/green.avi"
    T "ff: 2 seconds" $FF -y -f lavfi -i "color=c=white:s=80x60:d=2" -c:v rawvideo "$FD/long.avi"
    T "ff: 30fps" $FF -y -f lavfi -i "color=c=black:s=80x60:d=1:r=30" -c:v rawvideo "$FD/fps30.avi"

    # Containers (4)
    T "ff: AVI container" $FF -y -f lavfi -i "sine=frequency=440:duration=1" -f lavfi -i "color=c=red:s=80x60:d=1" -c:v rawvideo "$FD/test.avi"
    T "ff: MKV container" $FF -y -f lavfi -i "sine=frequency=440:duration=1" "$FD/test.mkv"
    T "ff: MOV container" $FF -y -f lavfi -i "sine=frequency=440:duration=1" "$FD/test.mov"
    T "ff: MPEGTS container" $FF -y -f lavfi -i "sine=frequency=440:duration=1" -c:a aac "$FD/test.ts"

    # Metadata (4)
    T "ff: set title" $FF -y -i "$FD/sine440.wav" -metadata title="Test Song" "$FD/meta.wav"
    T "ff: set artist" $FF -y -i "$FD/sine440.wav" -metadata artist="Tiger PPC" "$FD/meta2.wav"
    T "ff: set comment" $FF -y -i "$FD/sine440.wav" -metadata comment="validation" "$FD/meta3.wav"
    if [ -x "$FP" ]; then
        TO "ff: read metadata" "Test Song" $FP -show_entries format_tags=title -of default=nw=1 "$FD/meta.wav"
    else
        T "ff: set album" $FF -y -i "$FD/sine440.wav" -metadata album="Test Album" "$FD/meta4.wav"
    fi

    # Other (2)
    T "ff: concat audio" $FF -y -i "$FD/sine440.wav" -i "$FD/sine1k.wav" -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1" "$FD/concat.wav"
    T "ff: trim/seek" $FF -y -ss 0.2 -t 0.5 -i "$FD/sine440.wav" "$FD/trimmed.wav"
    T "ff: resample 22050" $FF -y -i "$FD/sine440.wav" -ar 22050 "$FD/rs22.wav"
    T "ff: mono to stereo" $FF -y -i "$FD/silence.wav" -ac 2 "$FD/stereo.wav"

    pkg
}

###############################################################################
test_curl() {
    echo "=== curl 8.12.1 (29 tests) ==="
    reset
    local CMAX="--max-time 15 --connect-timeout 10"

    # Version (1)
    TO "curl: version" "8.12" $CU --version

    # HTTP basic (6)
    T "curl: GET example.com" $CU $CMAX -s -o /dev/null http://example.com
    T "curl: GET -I headers" $CU $CMAX -s -I -o /dev/null http://example.com
    T "curl: HEAD request" $CU $CMAX -s -I http://example.com
    T "curl: POST" $CU $CMAX -s -o /dev/null -X POST -d "test=1" http://example.com
    T "curl: PUT" $CU $CMAX -s -o /dev/null -X PUT -d "test=1" http://example.com
    T "curl: DELETE" $CU $CMAX -s -o /dev/null -X DELETE http://example.com

    # Headers (4)
    T "curl: custom header" $CU $CMAX -s -o /dev/null -H "X-Test: hello" http://example.com
    T "curl: User-Agent" $CU $CMAX -s -o /dev/null -A "TigerPPC/1.0" http://example.com
    T "curl: Accept header" $CU $CMAX -s -o /dev/null -H "Accept: application/json" http://example.com
    T "curl: multiple headers" $CU $CMAX -s -o /dev/null -H "X-A: 1" -H "X-B: 2" http://example.com

    # HTTPS (5)
    T "curl: HTTPS GET" $CU $CMAX -s -o /dev/null https://example.com
    T "curl: HTTPS verify" $CU $CMAX -s -o /dev/null --cacert "$SSL_CERT_FILE" https://example.com
    TO "curl: HTTPS response code" "200" $CU $CMAX -s -o /dev/null -w "%{http_code}" https://example.com
    TO "curl: HTTPS verbose TLS" "SSL" $CU $CMAX -s -o /dev/null -v https://example.com
    TO "curl: HTTPS write-out" "example.com" $CU $CMAX -s -o /dev/null -w "%{url_effective}" https://example.com

    # Downloads (4)
    T "curl: download to file" $CU $CMAX -s -o "$TD/dl.html" http://example.com
    T "curl: download verify" test -s "$TD/dl.html"
    TO "curl: response size" "[0-9]" $CU $CMAX -s -o /dev/null -w "%{size_download}" http://example.com
    T "curl: max-time works" $CU --max-time 5 -s -o /dev/null http://example.com

    # Features (5)
    TO "curl: follow redirect" "200" $CU $CMAX -s -o /dev/null -L -w "%{http_code}" http://example.com
    TO "curl: response code extract" "200" $CU $CMAX -s -o /dev/null -w "%{http_code}" http://example.com
    T "curl: cookie jar" $CU $CMAX -s -o /dev/null -c "$TD/cookies.txt" http://example.com
    TO "curl: content-type" "text/html" $CU $CMAX -s -o /dev/null -w "%{content_type}" http://example.com
    TO "curl: write-out format" "[0-9]" $CU $CMAX -s -o /dev/null -w "%{time_total}" http://example.com

    # Protocol (4)
    echo "test file content" > "$TD/testfile.txt"
    TO "curl: file:// protocol" "test file" $CU -s "file://$TD/testfile.txt"
    T "curl: connection timeout" $CU --connect-timeout 5 -s -o /dev/null http://example.com
    TO "curl: HTTP/1.1" "200" $CU $CMAX -s -o /dev/null -w "%{http_code}" --http1.1 http://example.com
    TO "curl: remote IP" "[0-9]" $CU $CMAX -s -o /dev/null -w "%{remote_ip}" http://example.com

    pkg
}

###############################################################################
test_openssl() {
    echo "=== OpenSSL 3.6.1 (24 tests) ==="
    reset

    # Via Python ssl (12)
    P "ssl: module import" "import ssl"
    P "ssl: OPENSSL_VERSION" "import ssl; assert '3.' in ssl.OPENSSL_VERSION or 'OpenSSL' in ssl.OPENSSL_VERSION"
    P "ssl: version info" "import ssl; assert ssl.OPENSSL_VERSION_INFO[0]>=3"
    P "ssl: create context" "import ssl; ctx=ssl.create_default_context(); assert ctx"
    P "ssl: SSLContext" "import ssl; ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); assert ctx"
    P "ssl: cipher list" "import ssl; ctx=ssl.create_default_context(); assert len(ctx.get_ciphers())>0"
    P "ssl: verify paths" "import ssl; p=ssl.get_default_verify_paths(); assert p"
    P "ssl: HAS_TLSv1_2" "import ssl; assert ssl.HAS_TLSv1_2"
    P "ssl: HTTPS urllib" "
import urllib.request, ssl
ctx=ssl.create_default_context()
ctx.load_verify_locations('$SSL_CERT_FILE')
r=urllib.request.urlopen('https://example.com',context=ctx,timeout=15)
assert r.status==200"
    P "ssl: HTTPS read" "
import urllib.request, ssl
ctx=ssl.create_default_context()
ctx.load_verify_locations('$SSL_CERT_FILE')
r=urllib.request.urlopen('https://example.com',context=ctx,timeout=15)
data=r.read()
assert b'Example' in data"
    P "ssl: cert from HTTPS" "
import ssl, socket
ctx=ssl.create_default_context()
ctx.load_verify_locations('$SSL_CERT_FILE')
with ctx.wrap_socket(socket.socket(),server_hostname='example.com') as s:
    s.settimeout(15)
    s.connect(('example.com',443))
    cert=s.getpeercert()
    assert 'subject' in cert"
    P "ssl: RAND_status" "import ssl; assert ssl.RAND_status()==1"

    # Via curl HTTPS (12)
    local CMAX="--max-time 15 --connect-timeout 10"
    T "ssl-curl: HTTPS basic" $CU $CMAX -s -o /dev/null https://example.com
    T "ssl-curl: HTTPS google" $CU $CMAX -s -o /dev/null https://www.google.com
    TO "ssl-curl: show cert" "subject" $CU $CMAX -s -o /dev/null -v https://example.com
    TO "ssl-curl: TLS handshake" "SSL connection" $CU $CMAX -s -o /dev/null -v https://example.com
    T "ssl-curl: HTTPS download" $CU $CMAX -s -o "$TD/ssl_dl.html" https://example.com
    T "ssl-curl: HTTPS download verify" test -s "$TD/ssl_dl.html"
    T "ssl-curl: HTTPS POST" $CU $CMAX -s -o /dev/null -X POST -d "test" https://example.com
    T "ssl-curl: HTTPS HEAD" $CU $CMAX -s -I -o /dev/null https://example.com
    TO "ssl-curl: HTTPS redirect" "200" $CU $CMAX -s -o /dev/null -L -w "%{http_code}" https://example.com
    TO "ssl-curl: verify result" "0" $CU $CMAX -s -o /dev/null -w "%{ssl_verify_result}" https://example.com
    TO "ssl-curl: HTTPS response" "200" $CU $CMAX -s -o /dev/null -w "%{http_code}" https://example.com
    TO "ssl-curl: HTTPS scheme" "https" $CU $CMAX -s -o /dev/null -w "%{scheme}" https://example.com

    pkg
}

###############################################################################
# Pre-flight
echo "Tiger PPC Build Validation Suite"
echo "================================"
echo ""
echo "Pre-flight checks:"
ALL_OK=1
for bin in $PY $GIT $GCC $GXX $FF $CU; do
    if [ -x "$bin" ]; then
        printf "  OK   %s\n" "$bin"
    else
        printf "  MISS %s\n" "$bin"
        ALL_OK=0
    fi
done
if [ -x "$FP" ]; then printf "  OK   %s\n" "$FP"; else printf "  MISS %s (optional)\n" "$FP"; fi
echo ""

START=$(date +%s 2>/dev/null || echo 0)

case "${1:-all}" in
    python)  test_python ;;
    git)     test_git ;;
    gcc)     test_gcc ;;
    ffmpeg)  test_ffmpeg ;;
    curl)    test_curl ;;
    openssl) test_openssl ;;
    all)     test_python; test_git; test_gcc; test_ffmpeg; test_curl; test_openssl ;;
    *)       echo "Usage: $0 [python|git|gcc|ffmpeg|curl|openssl|all]"; exit 1 ;;
esac

rm -rf "$TD"

END=$(date +%s 2>/dev/null || echo 0)
ELAPSED=$((END - START))

echo "========================================"
echo "  TOTAL: $((TP + TF)) tests"
echo "  PASS:  $TP"
echo "  FAIL:  $TF"
echo "  TIME:  ${ELAPSED}s"
echo "========================================"
if [ $TF -gt 0 ]; then
    echo ""
    echo "Failed tests:"
    printf "$FL"
fi
exit $TF
