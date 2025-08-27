// Copyright 2017 ETH Zurich and University of Bologna.
// My custom program for PULPino RISC-V processor

#include <stdio.h>

int main()
{
    printf("Welcome to my custom program!\n");
    
    // Simple calculation example
    int a = 10;
    int b = 20;
    int sum = a + b;
    
    printf("The sum of %d + %d = %d\n", a, b, sum);
    
    // Simple loop example
    printf("Counting from 1 to 5:\n");
    for(int i = 1; i <= 5; i++) {
        printf("Count: %d\n", i);
    }
    
    printf("Program completed successfully!\n");
    return 0;
}
