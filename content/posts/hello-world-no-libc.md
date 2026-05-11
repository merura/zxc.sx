---
title: "Hello World Without Libc: A Deep Dive into How Programs Really Work"
date: 2026-05-11T21:08:19+05:00
tags: ["linux", "c", "assembly", "system-programming", "x86-64", "kernel", "operating-systems"]
categories: ["tutorial", "deep-dive"]
---

## Introduction

Most programmers start with a simple "Hello World" program like this:

```c
#include <stdio.h>

int main(void) {
    printf("hello world\n");
    return 0;
}
```

But have you ever wondered what really happens under the hood? What is `printf` doing? Where does `main` come from? What happens before `main` is called? How does the program actually communicate with the operating system to display text on the screen?

In this article, we're going to build a "Hello World" program in C that requires **no standard library** (no libc). We'll write directly to the screen using system calls, and in the process, we'll understand:

- How computers work at the hardware level
- What an operating system does
- The difference between kernel space and user space
- How processes are created and managed
- What system calls are and how they work
- How memory is organized in a program
- Every single line of our code, down to the assembly instructions

Here's the complete program we'll be dissecting:

```c
static inline long syscall3(long n, long a1, long a2, long a3)
{
    long ret;
    __asm__ volatile (
        "syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1), "S"(a2), "d"(a3)
        : "rcx", "r11", "memory"
    );
    return ret;
}

static inline long syscall1(long n, long a1)
{
    long ret;
    __asm__ volatile (
        "syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1)
        : "rcx", "r11", "memory"
    );
    return ret;
}

__attribute__((noreturn))
void _start(void)
{
    const char msg[] = "hello world\n";

    syscall3(1, 1, (long)msg, sizeof(msg) - 1);
    syscall1(60, 0);

    __builtin_unreachable();
}
```

We compile it like this:

```bash
gcc -nostdlib -static main.c
./a.out
# Output: hello world
```

By the end of this article, you'll understand every single piece of this code and the computer science fundamentals that make it work. Let's start from the very beginning.

## Part 1: How Computers Work at the Hardware Level

### The Central Processing Unit (CPU)

At its core, a computer is remarkably simple. The CPU (Central Processing Unit) is the brain of the computer, and it does one fundamental thing: it executes instructions. The CPU operates in a continuous cycle called the **fetch-decode-execute cycle**:

1. **Fetch**: Read an instruction from memory
2. **Decode**: Figure out what the instruction means
3. **Execute**: Perform the instruction
4. **Repeat**: Move to the next instruction

That's it. Every program you've ever written, every game you've ever played, every video you've watched - it all boils down to the CPU endlessly fetching, decoding, and executing instructions.

### Registers: The CPU's Built-in Variables

The CPU needs a place to work with data. While memory (RAM) exists outside the CPU, accessing it is relatively slow. So the CPU has its own ultra-fast storage called **registers**. Think of registers as the CPU's built-in variables.

On x86-64 architecture (modern 64-bit Intel/AMD processors), there are several types of registers:

**General Purpose Registers** (64-bit):
- `RAX` - Accumulator (often used for return values)
- `RBX` - Base register
- `RCX` - Counter register
- `RDX` - Data register
- `RSI` - Source index (often used for source pointer in memory operations)
- `RDI` - Destination index (often used for destination pointer)
- `RBP` - Base pointer (points to the base of the current stack frame)
- `RSP` - Stack pointer (points to the top of the stack)
- `R8` through `R15` - Additional general purpose registers

**Special Purpose Registers**:
- `RIP` - Instruction pointer (points to the next instruction to execute)
- `RFLAGS` - Flags register (stores condition flags like zero, carry, sign, etc.)

Each 64-bit register can also be accessed in smaller sizes:
- `RAX` (64-bit) → `EAX` (lower 32 bits) → `AX` (lower 16 bits) → `AH`/`AL` (high/low 8 bits)

### Memory Hierarchy

Computers have multiple levels of storage, arranged by speed and size:

1. **Registers**: Inside the CPU, fastest, smallest (dozens of 64-bit values)
2. **L1 Cache**: On-chip, very fast, small (typically 32-64 KB per core)
3. **L2 Cache**: On-chip, fast, medium (typically 256-512 KB per core)
4. **L3 Cache**: On-chip, fast, larger (typically 8-32 MB shared)
5. **RAM**: Off-chip, slower, large (typically 8-64 GB)
6. **Disk/SSD**: Much slower, huge (typically 256 GB - several TB)

When you write a program, your variables live in RAM, but the CPU constantly moves small chunks of data into its caches and registers to work with them.

### Von Neumann Architecture

Modern computers follow the **Von Neumann architecture**, which has one key insight: **code is just data**. Programs and data both live in the same memory. The CPU doesn't fundamentally distinguish between an instruction and a piece of data - they're both just numbers in memory.

This is crucial to understand. When you write:
```c
int x = 42;
```

The number `42` is stored in memory. But instructions are also stored as numbers. For example, the x86-64 instruction to add 5 to the RAX register might be encoded as the bytes `48 83 C0 05`. The CPU fetches these bytes, decodes them, and executes the addition.

### x86-64 Specifics: 64-bit vs 32-bit

The "64-bit" in x86-64 refers to several things:
- Registers are 64 bits wide (can hold numbers from 0 to 2^64-1)
- Memory addresses are 64 bits (theoretically allowing 16 exabytes of RAM)
- The CPU can process 64 bits of data in a single operation

In practice, current CPUs use only 48 bits for addressing (256 TB of addressable memory), which is still vastly more than any consumer computer has.

### Machine Code and Binary

Everything the CPU executes is ultimately **machine code** - sequences of bytes that encode instructions. For example:

```
48 C7 C0 01 00 00 00    mov rax, 1
0F 05                   syscall
```

The first instruction (`mov rax, 1`) is encoded as 7 bytes: `48 C7 C0 01 00 00 00`. The second instruction (`syscall`) is just 2 bytes: `0F 05`.

Writing programs in raw machine code would be insane, so we use **assembly language** as a human-readable representation:

```asm
mov rax, 1      ; Move the value 1 into the RAX register
syscall         ; Invoke a system call
```

And we use high-level languages like C to write code that's even more readable, which then gets compiled down to assembly, and then assembled into machine code.

## Part 2: Operating System Fundamentals

### What is an Operating System?

When you turn on your computer, the CPU starts executing code. But it doesn't start executing your program - it starts executing the **operating system** (OS). The operating system is just a program, but it's a special one that:

1. **Manages hardware resources**: CPU time, memory, disk, network, graphics, etc.
2. **Provides abstractions**: Files instead of raw disk sectors, processes instead of raw CPU time, sockets instead of raw network packets
3. **Enforces isolation and security**: Prevents programs from interfering with each other
4. **Schedules processes**: Decides which program gets to run on the CPU when

The OS is like a traffic controller for the computer. Without it, every program would need to know how to drive your specific hard drive model, manage memory conflicts with other programs, and coordinate access to shared resources. The OS abstracts all of this away.

On Linux, the core OS is called the **kernel**. The Linux kernel is what actually runs on the CPU and manages everything.

### Kernel Space vs User Space

This is one of the most important concepts in operating systems. Modern CPUs support different **privilege levels**, often called "rings":

- **Ring 0** (kernel mode): The CPU can do anything - access any memory, execute privileged instructions, access hardware directly
- **Ring 3** (user mode): The CPU is restricted - can only access its own memory, cannot execute privileged instructions, cannot access hardware directly

The operating system kernel runs in Ring 0 (kernel mode). Your programs run in Ring 3 (user mode).

**Why this separation?**

Imagine if every program could access any memory, including other programs' memory. A bug in your web browser could corrupt your text editor's data. A malicious program could read your password manager's memory. Chaos would ensue.

By running user programs in a restricted mode, the OS ensures:
- **Memory isolation**: Your program can only access its own memory
- **Security**: Malicious programs can't directly access hardware (like reading your webcam or keystrokes)
- **Stability**: A crash in one program doesn't bring down the whole system

Here's a simplified view of the memory layout:

```
0xFFFFFFFFFFFFFFFF  ┌─────────────────┐
                    │  Kernel Space   │  Ring 0 only
                    │  (OS kernel)    │
                    ├─────────────────┤
                    │  User Space     │  Ring 3
                    │  (Your program) │
0x0000000000000000  └─────────────────┘
```

### The Problem: How Do User Programs Do Anything Useful?

If user programs can't access hardware, how do they do anything? How do they:
- Write to the screen?
- Read from a file?
- Send data over the network?
- Allocate more memory?

The answer is **system calls**.

### System Calls: The Bridge Between User and Kernel Space

A **system call** (syscall) is a controlled way for user programs to ask the kernel to do something on their behalf. It's like raising your hand in class to ask the teacher for help.

Here's how a system call works:

1. **User program prepares arguments**: Put syscall number and arguments in specific registers
2. **Execute syscall instruction**: The CPU executes a special `syscall` instruction
3. **Mode switch**: The CPU automatically switches from Ring 3 to Ring 0
4. **Kernel handles request**: The kernel looks at the syscall number, validates arguments, performs the operation
5. **Return to user space**: The kernel puts the result in a register and switches back to Ring 3
6. **User program continues**: The program now has the result and continues executing

This mode switch is **extremely fast** - it happens in microseconds. Modern CPUs have dedicated hardware to make this efficient.

Let's look at a concrete example: writing "hello world" to the screen.

#### The write() System Call

To write data to the screen, we use the `write()` system call. On x86-64 Linux, this is syscall number **1**.

The `write()` syscall takes 3 arguments:
1. **File descriptor** (which output stream): `1` means stdout (the terminal)
2. **Buffer** (pointer to the data to write): Address of our "hello world" string
3. **Count** (how many bytes to write): Length of the string

#### x86-64 Linux System Call Calling Convention

On x86-64 Linux, system calls follow a specific convention:

**Input**:
- `RAX` register: System call number
- `RDI` register: 1st argument
- `RSI` register: 2nd argument
- `RDX` register: 3rd argument
- `R10` register: 4th argument (if needed)
- `R8` register: 5th argument (if needed)
- `R9` register: 6th argument (if needed)

**Output**:
- `RAX` register: Return value (or error code)

**Clobbered** (may be modified by the syscall):
- `RCX` register: Overwritten by syscall instruction (saves return address)
- `R11` register: Overwritten by syscall instruction (saves flags)

So to call `write(1, msg, 12)`:
```
RAX = 1      (syscall number for write)
RDI = 1      (file descriptor: stdout)
RSI = msg    (pointer to "hello world\n")
RDX = 12     (length of the string)
syscall      (execute the system call)
```

After the syscall returns, RAX will contain the number of bytes written (or a negative error code).

#### Common System Calls

Linux has hundreds of system calls. Here are a few important ones:

| Number | Name      | Purpose                          |
|--------|-----------|----------------------------------|
| 0      | read      | Read from file descriptor        |
| 1      | write     | Write to file descriptor         |
| 2      | open      | Open a file                      |
| 3      | close     | Close a file descriptor          |
| 9      | mmap      | Map memory                       |
| 60     | exit      | Terminate the process            |
| 57     | fork      | Create a new process             |
| 59     | execve    | Execute a program                |

You can find the complete list in `/usr/include/asm/unistd_64.h` or in the Linux kernel source.

## Part 3: Processes in Linux

### What is a Process?

A **process** is a running instance of a program. The distinction is important:
- **Program**: Static file on disk (the executable binary)
- **Process**: Running instance with its own memory, state, and resources

You can run the same program multiple times, and each execution is a separate process with its own memory and state.

Each process has:
- **Process ID (PID)**: Unique identifier (like process #1234)
- **Memory space**: Its own isolated view of memory
- **Open file descriptors**: References to open files, sockets, etc.
- **Registers state**: Current values of CPU registers
- **Execution state**: Running, sleeping, stopped, zombie

### Process Memory Layout

When the OS creates a process, it sets up a memory layout that looks like this (from low to high addresses):

```
High addresses
0xFFFFFFFFFFFFFFFF  ┌─────────────────────┐
                    │   Kernel Space      │ ← OS kernel (inaccessible from user mode)
                    ├─────────────────────┤
                    │   Stack             │ ← Local variables, function call frames
                    │   (grows downward)  │   (starts at high address, grows toward low)
                    │         ↓           │
                    ├─────────────────────┤
                    │   (unused)          │
                    ├─────────────────────┤
                    │         ↑           │
                    │   Heap              │ ← malloc/free allocate here
                    │   (grows upward)    │   (starts at low address, grows toward high)
                    ├─────────────────────┤
                    │   BSS Segment       │ ← Uninitialized global variables
                    ├─────────────────────┤
                    │   Data Segment      │ ← Initialized global variables
                    ├─────────────────────┤
                    │   Text Segment      │ ← Program code (machine instructions)
Low addresses       │   (read-only)       │
0x0000000000400000  └─────────────────────┘
```

Let's understand each section:

**Text Segment** (Code):
- Contains the actual machine code instructions
- Read-only and executable
- Shared between multiple instances of the same program

**Data Segment**:
- Initialized global and static variables
- Example: `int x = 42;` at global scope
- Read-write

**BSS Segment** (Block Started by Symbol):
- Uninitialized global and static variables
- Example: `int x;` at global scope
- Initialized to zero by the OS
- Doesn't take space in the executable file (just a note of how much to allocate)

**Heap**:
- Dynamically allocated memory (`malloc`, `free` in C)
- Grows upward (toward higher addresses)
- Managed by memory allocator

**Stack**:
- Local variables and function call information
- Grows downward (toward lower addresses)
- Each function call adds a "stack frame"
- Automatically managed (variables destroyed when function returns)

**Kernel Space**:
- Top of the address space
- Contains the OS kernel code and data
- Inaccessible from user mode (attempting to access causes a segmentation fault)

### How Processes Are Created

On Unix-like systems (including Linux), new processes are created using two system calls: `fork()` and `exec()`.

**fork()** - System call 57:
- Creates an exact copy of the current process
- The child process gets a copy of the parent's memory
- Returns 0 to the child, returns child's PID to the parent
- Both processes continue executing from the same point

**execve()** - System call 59:
- Replaces the current process's memory with a new program
- Loads a new executable from disk
- Sets up the new memory layout
- Starts executing from the new program's entry point

Here's how your shell runs a program:

```c
// Simplified shell pseudocode
void run_program(char *path) {
    pid_t pid = fork();           // Create child process

    if (pid == 0) {
        // We're in the child process
        execve(path, args, env);  // Replace with the new program
        // If execve succeeds, we never return
    } else {
        // We're in the parent (shell)
        wait(pid);                // Wait for child to finish
    }
}
```

### Process Startup: From Disk to Execution

When you run `./a.out`, here's what happens:

1. **Shell forks**: Creates a child process (copy of the shell)
2. **Child calls execve("./a.out")**: Kernel begins loading the program
3. **Kernel reads ELF header**: The executable file format on Linux is ELF (Executable and Linkable Format)
4. **Kernel sets up memory**:
   - Maps text segment (code) into memory
   - Maps data segment into memory
   - Allocates BSS segment (zeroed)
   - Sets up stack
   - Sets up heap (empty initially)
5. **Kernel prepares registers**:
   - Sets `RSP` (stack pointer) to top of stack
   - Sets `RIP` (instruction pointer) to entry point address
6. **Kernel switches to user mode**: CPU begins executing your program

#### The Entry Point

For normal C programs compiled with libc, the entry point is a function called `_start` (provided by libc). This function:
1. Initializes the C runtime
2. Sets up `argc`, `argv`, and environment variables
3. Calls global constructors
4. Calls `main()`
5. Calls `exit()` with main's return value

But we're not using libc, so we provide our own `_start` function, and it's much simpler - we just do our work and exit directly.

## Part 4: The Role of Libc (and Why We're Skipping It)

### What is Libc?

The C standard library (libc, usually GNU libc or "glibc" on Linux) is a collection of functions that provide:

**System call wrappers**:
```c
// Instead of manually doing syscalls, you call:
write(1, "hello", 5);    // Calls syscall under the hood
read(0, buffer, 100);
open("/tmp/file", O_RDONLY);
```

**Standard library functions**:
```c
printf("hello %d\n", 42);  // Formatted output
malloc(1024);              // Memory allocation
strlen("hello");           // String operations
fopen("file.txt", "r");    // File I/O
```

**Runtime initialization**:
- Sets up the C runtime environment
- Initializes global constructors
- Provides the `_start` entry point
- Prepares `argc`/`argv`
- Calls your `main()` function
- Handles return from `main()` (calls `exit()`)

**Linking**:
Libc can be linked two ways:
- **Dynamic linking** (default): The libc code lives in a shared library (`.so` file) that's loaded at runtime
- **Static linking**: The libc code is copied into your executable at compile time

### Why Skip Libc?

For learning purposes, skipping libc is incredibly valuable:
- **Understanding fundamentals**: You see exactly what's happening
- **Direct control**: No hidden initialization or magic
- **Minimal binary size**: Our program will be much smaller
- **System call knowledge**: You learn how to interact with the OS directly

In production, you usually want libc because:
- It's well-tested and optimized
- It provides portability
- It includes tons of useful functions
- It handles edge cases and error conditions

But for education, let's build without it.

## Part 5: Assembly Language - The Human-Readable Machine Code

Before we dive into our code, we need to understand assembly language and how it integrates with C.

### x86-64 Assembly Basics

Assembly language is a human-readable representation of machine code. Each assembly instruction corresponds to a machine code instruction.

**Syntax Flavors**:
There are two main syntax styles for x86 assembly:
- **Intel syntax**: `mov rax, 1` (destination first)
- **AT&T syntax**: `movq $1, %rax` (source first, register names have `%`, immediates have `$`)

GCC uses AT&T syntax by default, but the machine code is the same either way.

**Common Instructions**:
```asm
mov rax, 1          ; Copy value 1 into RAX register
add rax, 5          ; Add 5 to RAX
sub rax, 3          ; Subtract 3 from RAX
syscall             ; Invoke a system call
ret                 ; Return from function
push rax            ; Push RAX onto the stack
pop rax             ; Pop from stack into RAX
```

### Inline Assembly in C

C allows you to embed assembly code directly using the `__asm__` keyword (GCC extension):

```c
__asm__ volatile (
    "instruction"
    : outputs
    : inputs
    : clobbers
);
```

Let's break this down:

**volatile**: Tells the compiler not to optimize this assembly away

**"instruction"**: The actual assembly instruction(s)

**outputs**: Variables that this assembly writes to
- Format: `"constraint"(variable)`
- Example: `"=a"(ret)` means "write RAX to variable `ret`"

**inputs**: Variables that this assembly reads from
- Format: `"constraint"(variable)`
- Example: `"a"(n)` means "put variable `n` into RAX"

**clobbers**: Registers/memory that this assembly modifies
- Example: `"rcx", "r11", "memory"` means "this modifies RCX, R11, and possibly memory"

### Register Constraints

These tell GCC how to map C variables to registers:
- `"a"` - RAX register
- `"b"` - RBX register
- `"c"` - RCX register
- `"d"` - RDX register
- `"S"` - RSI register
- `"D"` - RDI register
- `"r"` - Any general purpose register
- `"m"` - Memory location

Output constraints use `=` prefix:
- `"=a"` - Write to RAX (output)
- `"a"` - Read from RAX (input)

## Part 6: The System Calls We Use

Our program uses two system calls:

### System Call 1: write

```c
ssize_t write(int fd, const void *buf, size_t count);
```

**Purpose**: Write data to a file descriptor

**Arguments**:
1. `fd` (file descriptor): Where to write
   - 0 = stdin (standard input)
   - 1 = stdout (standard output)
   - 2 = stderr (standard error)
   - Higher numbers are for opened files
2. `buf` (buffer): Pointer to the data to write
3. `count`: Number of bytes to write

**Return value**: Number of bytes written, or -1 on error

**System call number**: 1 (on x86-64 Linux)

For our program: `write(1, "hello world\n", 12)` writes 12 bytes to stdout.

### System Call 60: exit

```c
void exit(int status);
```

**Purpose**: Terminate the current process

**Arguments**:
1. `status`: Exit code
   - 0 = success
   - Non-zero = error (convention)

**Return value**: Never returns

**System call number**: 60 (on x86-64 Linux)

For our program: `exit(0)` terminates with success code.

## Part 7: The Complete Code - Line by Line

Now we're ready to understand every single line of our program. Let's go through it piece by piece.

### The syscall3 Function

```c
static inline long syscall3(long n, long a1, long a2, long a3)
{
    long ret;
    __asm__ volatile (
        "syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1), "S"(a2), "d"(a3)
        : "rcx", "r11", "memory"
    );
    return ret;
}
```

Let's break this down word by word:

**`static`**: This function is only visible in this source file (internal linkage)

**`inline`**: Hint to the compiler to insert the function body directly at call sites rather than making a function call (optimization)

**`long syscall3`**: Returns a `long` (64-bit integer) and is named `syscall3` (because it takes 3 arguments)

**`(long n, long a1, long a2, long a3)`**: Parameters:
- `n` - system call number
- `a1` - first argument
- `a2` - second argument
- `a3` - third argument

**`long ret;`**: Variable to store the return value from the system call

**`__asm__ volatile (`**: Begin inline assembly block (volatile prevents optimization)

**`"syscall"`**: The assembly instruction to execute. This single instruction:
- Saves current RIP (instruction pointer) to RCX
- Saves RFLAGS to R11
- Loads the system call handler address from MSR
- Switches CPU to Ring 0 (kernel mode)
- Jumps to the kernel system call handler

**`: "=a"(ret)`**: Output operand
- `=a` means "write to RAX register"
- `(ret)` means "store RAX's value into the `ret` variable after the syscall"
- This captures the return value of the system call

**`: "a"(n), "D"(a1), "S"(a2), "d"(a3)`**: Input operands (what goes IN to the assembly)
- `"a"(n)` - Put `n` (syscall number) into RAX register
- `"D"(a1)` - Put `a1` (first arg) into RDI register
- `"S"(a2)` - Put `a2` (second arg) into RSI register
- `"d"(a3)` - Put `a3` (third arg) into RDX register

These match the x86-64 Linux syscall calling convention.

**`: "rcx", "r11", "memory"`**: Clobber list (registers/memory modified by this assembly)
- `"rcx"` - The syscall instruction overwrites RCX (with return RIP)
- `"r11"` - The syscall instruction overwrites R11 (with RFLAGS)
- `"memory"` - Syscall may modify memory (prevents unsafe optimizations)

**`return ret;`**: Return the syscall's return value

So when we call `syscall3(1, 1, (long)msg, 12)`:
1. RAX gets 1 (write syscall)
2. RDI gets 1 (stdout)
3. RSI gets the address of msg
4. RDX gets 12 (length)
5. `syscall` instruction executes
6. Kernel writes "hello world\n" to stdout
7. Kernel returns number of bytes written to RAX
8. RAX is copied to `ret`
9. Function returns `ret`

### The syscall1 Function

```c
static inline long syscall1(long n, long a1)
{
    long ret;
    __asm__ volatile (
        "syscall"
        : "=a"(ret)
        : "a"(n), "D"(a1)
        : "rcx", "r11", "memory"
    );
    return ret;
}
```

This is almost identical to `syscall3`, but only takes one argument:
- `n` goes to RAX (syscall number)
- `a1` goes to RDI (first argument)

We use this for the `exit()` syscall which only needs one argument (the exit code).

### The _start Function

```c
__attribute__((noreturn))
void _start(void)
{
    const char msg[] = "hello world\n";

    syscall3(1, 1, (long)msg, sizeof(msg) - 1);
    syscall1(60, 0);

    __builtin_unreachable();
}
```

This is the entry point of our program. Let's break it down:

**`__attribute__((noreturn))`**: This is a GCC function attribute that tells the compiler:
- This function never returns to its caller
- The compiler can optimize accordingly
- Don't generate return code for this function
- Don't warn about missing return statement

This is appropriate because we call `exit()` at the end, which terminates the process.

**`void _start(void)`**: Function named `_start` with no parameters and no return value

The name `_start` is special. When we compile with `-nostdlib`, the linker uses `_start` as the entry point (instead of looking for `main`). When the kernel executes our program, it sets the instruction pointer (RIP) to the address of `_start`.

**`const char msg[] = "hello world\n";`**: Declare a local array containing the string

Let's understand this in detail:
- `const` - Cannot be modified
- `char msg[]` - Array of characters
- `= "hello world\n"` - String literal (12 characters: 11 visible + newline)

**Important**: String literals in C are null-terminated. The actual data in memory is:
```
'h' 'e' 'l' 'l' 'o' ' ' 'w' 'o' 'r' 'l' 'd' '\n' '\0'
```
That's 13 bytes total (the last `\0` is the null terminator).

**Where does this live?**: Since it's a local variable with `const`, the compiler might:
- Put it in the `.rodata` section (read-only data)
- Or allocate it on the stack at runtime
- The exact behavior is an optimization choice

**`sizeof(msg)`**: This returns 13 (the full size including null terminator)

**`sizeof(msg) - 1`**: This gives us 12 (excluding null terminator)

We subtract 1 because we don't want to write the null terminator to the terminal. The null terminator is a C convention for string handling, not something we want to display.

**`syscall3(1, 1, (long)msg, sizeof(msg) - 1);`**: Call the `write()` syscall

Breaking down the arguments:
- First `1`: syscall number for `write`
- Second `1`: file descriptor (stdout)
- `(long)msg`: Cast the char array pointer to `long` (since our syscall wrapper takes `long`)
  - Arrays decay to pointers to their first element
  - We cast to `long` to match the function signature
  - The value is the memory address of the first character
- `sizeof(msg) - 1`: Number of bytes to write (12)

This writes "hello world\n" to the terminal.

**`syscall1(60, 0);`**: Call the `exit()` syscall

Breaking down the arguments:
- `60`: syscall number for `exit`
- `0`: exit status (success)

This terminates our process with exit code 0.

**`__builtin_unreachable();`**: Compiler optimization hint

This is a GCC builtin that tells the compiler: "If execution ever reaches this point, the behavior is undefined."

Since `exit()` never returns, we'll never actually reach this line. But the compiler doesn't know that `syscall1(60, 0)` never returns (from its perspective, it's just a function call). By adding `__builtin_unreachable()`, we inform the compiler's optimizer that everything after the `exit()` syscall is dead code.

Without this, the compiler might generate unnecessary cleanup code or warnings.

## Part 8: Compilation and Linking

Now let's understand how we turn this C code into an executable.

### The Compilation Command

```bash
gcc -nostdlib -static main.c
```

**`gcc`**: The GNU Compiler Collection (C compiler)

**`-nostdlib`**: Do not link against the standard library
- Don't link libc (no `printf`, `malloc`, etc.)
- Don't include startup files (no `__libc_start_main`)
- Don't use the standard `_start` (we provide our own)
- Results in a minimal binary with only our code

**`-static`**: Perform static linking
- Don't use dynamic libraries (.so files)
- Include all code directly in the executable
- Results in a standalone binary with no external dependencies
- Can confirm with `ldd a.out` which should say "not a dynamic executable"

**`main.c`**: Our source file

**Output**: `a.out` (default output name)

### The Compilation Process

GCC actually runs several stages:

**1. Preprocessing** (`cpp` - C Preprocessor):
- Expands macros
- Includes header files
- Handles `#ifdef` directives
- Our code has no preprocessor directives, so this stage is trivial

**2. Compilation** (`cc1` - C Compiler):
- Parses C code into Abstract Syntax Tree (AST)
- Performs type checking
- Generates assembly code

**3. Assembly** (`as` - Assembler):
- Converts assembly code to object code (machine code)
- Produces an object file (`.o`)
- Contains machine code and symbol information

**4. Linking** (`ld` - Linker):
- Combines object files
- Resolves symbol references
- Creates final executable
- Sets entry point to `_start`
- Generates ELF binary

You can see these stages with:
```bash
gcc -nostdlib -static -v main.c
```

### What Happens During Linking

The linker's job is to:
1. **Find all symbols**: Functions and variables
2. **Resolve references**: Connect function calls to their definitions
3. **Assign addresses**: Give each piece of code/data a memory address
4. **Set the entry point**: Tell the kernel where to start executing (our `_start`)
5. **Create the ELF structure**: Package everything into the ELF format

With `-nostdlib`, the linker:
- Uses `_start` as the entry point (default is usually `_start` from libc)
- Doesn't link any standard libraries
- Produces a minimal executable

## Part 9: The ELF Binary Format

Our program produces an ELF (Executable and Linkable Format) binary. This is the standard executable format on Linux.

### ELF Structure

An ELF file contains:

**ELF Header** (first ~64 bytes):
- Magic number (`0x7F 'E' 'L' 'F'`)
- Architecture info (64-bit, x86-64)
- Entry point address (address of `_start`)
- Offsets to program headers and section headers

**Program Headers**:
- Describe segments (portions of the file to load into memory)
- Example: "Load bytes 0x1000-0x2000 from file to address 0x400000 with read+execute permissions"

**Section Headers**:
- Describe sections (logical divisions for linking/debugging)
- Examples: `.text` (code), `.data` (data), `.rodata` (read-only data), `.bss` (uninitialized data)

**Actual Code and Data**:
- The machine code instructions
- String literals
- Global variables

### Examining Our Binary

Let's check that it's truly standalone:

```bash
ldd a.out
```

Output:
```
not a dynamic executable
```

Perfect! No dependencies on shared libraries.

Check the size:
```bash
ls -lh a.out
```

Typical output: ~8-16 KB

Why so large when our code is so small? ELF format overhead:
- ELF headers
- Program headers
- Section headers
- Alignment padding
- Optional debugging info

The actual code is probably only a few dozen bytes.

### Viewing the Assembly

We can disassemble the binary to see the actual machine code:

```bash
objdump -d a.out
```

You'll see something like:

```asm
0000000000401000 <_start>:
  401000:   48 83 ec 10             sub    $0x10,%rsp
  401004:   48 b8 68 65 6c 6c 6f    movabs $0xa646c726f77206c,%rax
  40100b:   20 77 6f
  40100e:   48 89 04 24             mov    %rax,(%rsp)
  401012:   c7 44 24 08 6c 64 0a 00 movl   $0xa646c,0x8(%rsp)
  40101a:   ba 0c 00 00 00          mov    $0xc,%edx
  40101f:   48 89 e6                mov    %rsp,%rsi
  401022:   bf 01 00 00 00          mov    $0x1,%edi
  401027:   b8 01 00 00 00          mov    $0x1,%eax
  40102c:   0f 05                   syscall
  40102e:   bf 00 00 00 00          mov    $0x0,%edi
  401033:   b8 3c 00 00 00          mov    $0x3c,%eax
  401038:   0f 05                   syscall
```

This is the actual machine code! You can see:
- Setting up the string on the stack
- Loading syscall number 1 (write) into EAX
- Loading arguments into EDI, ESI, EDX
- The `syscall` instruction (`0f 05`)
- Loading syscall number 60 (exit) into EAX
- Another `syscall` instruction

### Viewing Sections

```bash
objdump -h a.out
```

Shows sections like:
- `.text` - Code (executable)
- `.rodata` - Read-only data (maybe our string, or it might be on stack)
- `.eh_frame` - Exception handling info (even with no libc, GCC includes some)

## Part 10: Execution Flow - From Shell to Screen

Now let's trace what happens when we type `./a.out` and hit Enter.

### Step 1: Shell Receives Command

Your shell (bash, zsh, etc.) reads the command `./a.out`.

### Step 2: Shell Forks

```c
pid_t child_pid = fork();  // Creates exact copy of shell process
```

Now there are two identical processes:
- Parent (original shell)
- Child (copy of shell)

Both continue executing from the same point, but `fork()` returns different values:
- Returns 0 to the child
- Returns child's PID to the parent

### Step 3: Child Calls exec

```c
if (child_pid == 0) {
    // We're the child
    execve("./a.out", argv, envp);
    // If we get here, exec failed
}
```

The `execve()` syscall:
1. Reads `./a.out` from disk
2. Verifies it's a valid ELF executable
3. Throws away the current process memory (the shell copy)
4. Sets up new memory layout (text, data, stack, etc.)
5. Maps the executable into memory
6. Sets up registers (RSP points to stack, RIP points to entry point)
7. Switches to user mode and starts executing

### Step 4: Kernel Starts Our Program

The kernel sets:
- `RIP = address of _start` (from ELF entry point)
- `RSP = top of stack` (kernel set up a stack for us)

Then switches to user mode. The CPU now begins executing our `_start` function.

### Step 5: Our Code Executes

**`_start` begins**:
```c
const char msg[] = "hello world\n";
```

The string is either loaded from the binary or constructed on the stack. Either way, `msg` is now a pointer to the string's address.

**First syscall - write**:
```c
syscall3(1, 1, (long)msg, sizeof(msg) - 1);
```

1. RAX ← 1 (write syscall number)
2. RDI ← 1 (stdout file descriptor)
3. RSI ← address of "hello world\n"
4. RDX ← 12 (length)
5. Execute `syscall` instruction

**Inside the syscall instruction** (hardware level):
1. CPU saves RIP (return address) to RCX
2. CPU saves RFLAGS to R11
3. CPU switches from Ring 3 to Ring 0 (user mode → kernel mode)
4. CPU loads kernel's syscall handler address and jumps to it

**In the kernel** (Ring 0):
1. Kernel's syscall handler examines RAX (sees it's 1 = write)
2. Kernel validates arguments:
   - FD 1 is valid (stdout)
   - Buffer address is in user space
   - Length is reasonable
3. Kernel calls its internal `sys_write` function
4. Kernel writes the bytes to stdout (which is connected to the terminal)
5. Kernel puts return value in RAX (12 = bytes written)
6. Kernel executes `sysretq` instruction

**Back to user mode** (Ring 3):
1. CPU restores RIP from RCX (instruction after the syscall)
2. CPU restores RFLAGS from R11
3. CPU switches from Ring 0 to Ring 3 (kernel mode → user mode)
4. Execution continues in our code

The return value (12) is in RAX, which gets copied to `ret`, which gets returned from `syscall3`. We ignore it.

**Second syscall - exit**:
```c
syscall1(60, 0);
```

1. RAX ← 60 (exit syscall number)
2. RDI ← 0 (exit status)
3. Execute `syscall` instruction
4. Kernel's syscall handler sees RAX = 60
5. Kernel terminates the process
6. Kernel frees the process's memory
7. Kernel sets exit status to 0
8. Kernel marks process as zombie (waiting for parent to collect status)
9. Never returns to user mode

### Step 6: Shell Reaps Child

Back in the shell (the parent process), which called:

```c
wait(&status);  // Wait for child to finish
```

The kernel wakes up the shell, telling it the child has exited with status 0. The shell collects the exit status, cleans up the zombie process, and prints the next prompt:

```bash
user@t14s:~/tmp$
```

## Part 11: Experiments and Extensions

Now that you understand the code, let's verify some things and experiment.

### Verify System Call Numbers

System call numbers are defined in the kernel headers. You can find them:

```bash
grep "define __NR_write" /usr/include/asm/unistd_64.h
grep "define __NR_exit" /usr/include/asm/unistd_64.h
```

Output:
```
#define __NR_write 1
#define __NR_exit 60
```

These numbers are the ABI (Application Binary Interface) between user space and kernel space. They're stable and won't change (changing them would break all existing programs).

### Using strace

The `strace` tool intercepts and displays system calls:

```bash
strace ./a.out
```

Output:
```
execve("./a.out", ["./a.out"], 0x7ffd... /* 50 vars */) = 0
write(1, "hello world\n", 12)           = 12
exit(0)                                 = ?
+++ exited with 0 +++
```

You can see:
1. `execve` - Shell loading our program
2. `write` - Our write syscall (returns 12 bytes written)
3. `exit` - Our exit syscall (never returns)

### Disassemble the Binary

```bash
objdump -d a.out
```

This shows the actual machine code. Look for the `<_start>` section to see our function compiled to assembly.

### Check Binary Size

```bash
ls -lh a.out
```

A typical minimal program:
- Our program: ~8-16 KB
- Hello World with libc (dynamic): ~16 KB (small because libc is in shared library)
- Hello World with libc (static): ~700-900 KB (includes all of libc)

Our program is minimal, but still has ELF overhead. You can strip debug symbols to reduce it further:

```bash
strip a.out
ls -lh a.out
```

### View Raw Strings

```bash
strings a.out
```

You should see `hello world` in the output (among other things like ELF metadata).

## Part 12: Going Further

### Even More Minimal - Pure Assembly

You can write this in pure assembly (`.s` file) to have even more control:

```asm
.global _start

.section .rodata
msg:
    .ascii "hello world\n"
msg_len = . - msg

.section .text
_start:
    # write(1, msg, 12)
    mov $1, %rax        # syscall number
    mov $1, %rdi        # fd
    lea msg(%rip), %rsi # buffer
    mov $msg_len, %rdx  # count
    syscall

    # exit(0)
    mov $60, %rax       # syscall number
    xor %rdi, %rdi      # status = 0
    syscall
```

Compile with:
```bash
as -o hello.o hello.s
ld -o hello hello.o
./hello
```

This produces an even smaller binary (though still with ELF overhead).

### Absolute Minimal Binary

With advanced techniques (manually crafting ELF headers, overlapping sections), you can create executables under 200 bytes. This is a fun challenge but not practical. See "Tiny ELF" articles for more.

### Adding More Functionality

Try implementing:

**Read from stdin**:
```c
// syscall 0 = read
char buffer[100];
long n = syscall3(0, 0, (long)buffer, 100);
```

**Open a file**:
```c
// syscall 2 = open
long fd = syscall3(2, (long)"/tmp/test.txt", O_RDONLY, 0);
```

**Write to a file**:
```c
syscall3(1, fd, (long)msg, 12);
```

**Close a file**:
```c
// syscall 3 = close
syscall1(3, fd);
```

### Other Architectures

The concepts are the same, but details differ:

**ARM64 (aarch64)**:
- Uses `svc 0` instruction instead of `syscall`
- Uses registers X0-X7 for arguments
- Uses X8 for syscall number

**x86 (32-bit)**:
- Uses `int 0x80` instruction
- Uses EBX, ECX, EDX, ESI, EDI, EBP for arguments
- Uses EAX for syscall number

**RISC-V**:
- Uses `ecall` instruction
- Uses registers A0-A7 for arguments
- Uses A7 for syscall number

## Part 13: Conclusion - What We've Learned

Let's recap the journey we've taken. We started with a simple goal: print "hello world" without using the C standard library. To truly understand how to do that, we needed to understand:

**Computer Architecture**:
- How CPUs work (fetch-decode-execute)
- Registers and memory hierarchy
- x86-64 architecture specifics

**Operating System Design**:
- What an OS does (resource management, abstraction, isolation)
- Kernel space vs user space (Ring 0 vs Ring 3)
- Why this separation exists (security, stability)

**System Calls**:
- The bridge between user programs and the kernel
- How they work mechanically (register setup, `syscall` instruction, mode switch)
- The x86-64 Linux syscall calling convention

**Process Management**:
- What a process is (running program with memory and state)
- Process memory layout (text, data, BSS, heap, stack)
- How processes are created (`fork` and `exec`)
- How programs are loaded and started

**The Role of Libc**:
- What the C standard library provides
- Why it exists (convenience, portability, functionality)
- What we give up by skipping it
- What we gain (understanding, control, minimalism)

**Assembly Language**:
- Bridge between high-level languages and machine code
- x86-64 assembly basics
- Inline assembly in C with GCC

**Our Code**:
- Every single line explained
- Every keyword and operator understood
- How it compiles to assembly
- How it executes at runtime

**The Complete Flow**:
From typing `./a.out` in the shell, through fork/exec, loading the ELF binary, setting up memory, starting at `_start`, making system calls with CPU mode switches, kernel handlers writing to the terminal, exiting the process, and the shell reaping the child.

### Why This Matters

Even though you'll rarely write code like this in production, understanding these fundamentals is invaluable:

**Debugging**: When something goes wrong, you understand what's actually happening
**Performance**: You know what's expensive (syscalls, memory access patterns)
**Security**: You understand attack surfaces and privilege boundaries
**Systems Programming**: You can write code that interacts with the OS efficiently
**Learning New Things**: New concepts build on these fundamentals

Every high-level abstraction (classes, garbage collection, async/await, web frameworks) ultimately builds on these basics. The bits are still shuffling around in registers, the CPU is still fetching and executing instructions, and system calls are still bridging user and kernel space.

### Recommended Resources

Want to go deeper? Check out these resources:

**Books**:
- "Computer Systems: A Programmer's Perspective" by Bryant & O'Hallaron
- "Operating Systems: Three Easy Pieces" by Remzi & Andrea Arpaci-Dusseau (free online)
- "The Linux Programming Interface" by Michael Kerrisk

**Online Resources**:
- Linux syscall table: https://filippo.io/linux-syscall-table/
- x86-64 ABI documentation: https://gitlab.com/x86-psABIs/x86-64-ABI
- Intel Software Developer Manuals: https://www.intel.com/sdm
- GCC Inline Assembly HOWTO: https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html

**Practice**:
- Write more syscall wrappers (read, open, close, etc.)
- Build a tiny shell using fork/exec
- Implement a minimal malloc using the brk/mmap syscalls
- Try writing pure assembly programs

### Final Thoughts

The "hello world" program is often dismissed as trivial. But when you peel back the layers - when you understand the hardware, the operating system, the compilation process, and the runtime behavior - you realize just how much engineering and how many abstractions are involved in displaying 12 bytes on a screen.

The next time you write:
```c
printf("hello world\n");
```

You'll know that behind that simple function call is a universe of computer science: CPU registers, memory hierarchies, privilege rings, system calls, kernel handlers, file descriptor tables, TTY drivers, and more.

Welcome to the world of systems programming. Now you truly understand how computers work.

## The Complete Program

Here's the complete program one more time, with annotations:

```c
// Wrapper for system calls with 3 arguments
// Used for write(fd, buf, count)
static inline long syscall3(long n, long a1, long a2, long a3)
{
    long ret;  // Will hold the return value
    __asm__ volatile (
        "syscall"                    // Execute syscall instruction
        : "=a"(ret)                  // Output: RAX → ret
        : "a"(n), "D"(a1), "S"(a2), "d"(a3)  // Inputs: RAX, RDI, RSI, RDX
        : "rcx", "r11", "memory"     // Clobbered by syscall
    );
    return ret;
}

// Wrapper for system calls with 1 argument
// Used for exit(status)
static inline long syscall1(long n, long a1)
{
    long ret;  // Will hold the return value
    __asm__ volatile (
        "syscall"                    // Execute syscall instruction
        : "=a"(ret)                  // Output: RAX → ret
        : "a"(n), "D"(a1)            // Inputs: RAX, RDI
        : "rcx", "r11", "memory"     // Clobbered by syscall
    );
    return ret;
}

// Entry point - kernel starts execution here
__attribute__((noreturn))
void _start(void)
{
    // Our message to display (12 bytes + null terminator)
    const char msg[] = "hello world\n";

    // write(1, msg, 12) - write to stdout
    // syscall 1, fd 1 (stdout), buffer, length
    syscall3(1, 1, (long)msg, sizeof(msg) - 1);

    // exit(0) - terminate with success
    // syscall 60, status 0
    syscall1(60, 0);

    // Tell compiler this code is unreachable (exit never returns)
    __builtin_unreachable();
}
```

Compile and run:
```bash
gcc -nostdlib -static main.c -o hello
./hello
# Output: hello world
```

Congratulations! You now understand computer systems from the transistors to your terminal.
