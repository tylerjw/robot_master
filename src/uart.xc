/*
 * uart.xc
 *
 *  Created on: Mar 13, 2014
 *      Author: tylerjw
 */
#include <platform.h>
#include <stdio.h>
#include <xs1.h>
#include <uart.h>

int UARTDELAY = 10417; // 9600 baud ( 1 / baud * 100e6 )
//int UARTDELAY = 100; // 1 mil

void uart_init(int baud) {
    UARTDELAY = (100e6 / baud);
}

void tx_str(out port TX, char *str) {
    for(int i = 0; str[i] != 0; i++) {
        tx(TX, str[i]);
    }
}

void tx(out port TX, unsigned char byte){
    timer t;
    int time;
    t :> time;
    TX <: 0; //start bit
    for(int k = 0; k < 8; k++){
        time += UARTDELAY;
        t when timerafter(time) :> void;
        TX <: byte;
        byte = byte >> 1;
    }
    time += UARTDELAY;
    t when timerafter(time) :> void;
    TX <: 1; //stop bit
    time += UARTDELAY;
    t when timerafter(time) :> void; // in case you run it twice in a row
}

int rx(in port RX){ //not enough pins for an RX pin.
  timer t;
  int time;
  int byte = 0;
  int bit;
  int byteValid = 0;
  int testBit;
  t :> time;
  time += 100e7; // timeout value
  while(byteValid == 0){
      RX when pinseq(0) :> void;
      t :> time;
      time += UARTDELAY/2; //center on start bit
      RX :> testBit; //check start bit
      if(testBit == 0){ //start bit valid, continue;
          for(int k = 0; k < 8; k++){
              time += UARTDELAY;
              t when timerafter(time) :> void;
              RX :> bit;
              byte += bit << k;
          }
          time += UARTDELAY;
          t when timerafter(time) :> void; //center on stop bit
          RX :> testBit; //check stop bit
          if(testBit == 1){ //stop bit valid, exit loop and return value
              byteValid = 1;
          }
      }
  }
  return byte;
}
