/*
 * uart.h
 *
 *  Created on: Mar 13, 2014
 *      Author: tylerjw
 */

#ifndef UART_H_
#define UART_H_

extern out port DEBUGTX;

interface uart_int {
    void clear();
    int avalible_a();
    int avalible_b();
    char getc_a();
    char getc_b();
    int geti_a();
    int geti_b();
};

interface arduino_int {
    void clear();
    int avalible();
    int geti();
};

#define RX_BUF_SIZE          2000
#define NEXT(x)              ((x+1)%RX_BUF_SIZE)

//#define DEBUG

void extern delay(int delay);
void uart_init(int baud);
void tx(out port TX, unsigned char byte);
void tx_str(out port TX, char *str);
int rx(in port RX);

// handle two uarts using the uart_interface
void multiRX(interface uart_int server reader, interface arduino_int server arduino, in port RXA, in port RXB, in port ARDUINO);

#endif /* UART_H_ */
