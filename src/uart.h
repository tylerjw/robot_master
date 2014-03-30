/*
 * uart.h
 *
 *  Created on: Mar 13, 2014
 *      Author: tylerjw
 */

#ifndef UART_H_
#define UART_H_

void uart_init(int baud);
void tx(out port TX, unsigned char byte);
void tx_str(out port TX, char *str);
int rx(in port RX);

#endif /* UART_H_ */
