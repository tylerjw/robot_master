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

int fifo_length(int start, int end) {
    if(end == start) {
        return 0;
    } else if(end > start) {
        return end - start;
    }
    return (RX_BUF_SIZE - start) + end;
}

void multiRX(interface uart_int server reader, interface arduino_int server arduino, in port RXA, in port RXB, in port ARDUINO) {
    timer timera;
    timer timerb;
    timer arduino_timer;
    int timea;
    int timeb;
    int arduino_time;
    char valuea;
    char valueb;
    char arduino_value;
    char bytea;
    char byteb;
    char arduino_byte;
    int statea = 10; //10=wating for start bit, 9=checking valid start bit, (1-8)=# of bits left, 0=checking end bit
    int stateb = 10;
    int arduino_state = 10;
    int UARTdelay = UARTDELAY; //baud rate = 9600
    int arduinoUARTdelay = UARTDELAY; // baud rate of 9600

    timera :> timea;
    timerb :> timeb;
    arduino_timer :> arduino_time;

    char buffera[RX_BUF_SIZE];
    int starta = 0;
    int enda = 0;

    char bufferb[RX_BUF_SIZE];
    int startb = 0;
    int endb = 0;

    char arduino_buffer[RX_BUF_SIZE];
    int arduino_start = 0;
    int arduino_end = 0;

    char buffer[80];

    while(1){
        select{

            // CAMERA A ////////////////////////////////////////////////////////////////////
            case timera when timerafter(timea) :> timea://time to poll the uartA
                RXA :> valuea;
                switch(statea){
                    case 10:
                        if(valuea == 0){//valid start bit detected
                            statea = 9;
                            timea += UARTdelay/3;
                        }else{
                            timea += UARTdelay/3;
                        }
                        break;
                    case 9:
                        if(valuea == 0){//start bit validated
                            statea = 8;
                            timea += UARTdelay;
                        }else{
                            statea = 10;
                            timea += UARTdelay/3;
                        }
                        break;
#pragma fallthrough
                    case 8:
                        bytea = 0;
                    case 7:
                    case 6:
                    case 5:
                    case 4:
                    case 3:
                    case 2:
                    case 1:
                        bytea |= (valuea << (8 - statea));
                        statea--;
                        timea+=UARTdelay;
                        break;
                    case 0:
                        if(valuea == 1){//stop bit validated
                            statea = 10;
                            timea += UARTdelay/3;
                            //rxa <: bytea;
                            if(NEXT(enda) != starta) {
                                buffera[enda] = bytea;
                                enda = NEXT(enda); // advance the end
                            }
                        }else{
                            statea = 10;
                            timea += UARTdelay/3;
                        }
                        break;
                }
                break;

            // CAMERA B ////////////////////////////////////////////////////////
            case timerb when timerafter(timeb) :> timeb:
                RXB :> valueb;
                switch(stateb){
                    case 10:
                        if(valueb == 0){//valid start bit detected
                            stateb = 9;
                            timeb += UARTdelay/3;
                        }else{
                            timeb += UARTdelay/3;
                        }
                        break;
                    case 9:
                        if(valueb == 0){//start bit validated
                            stateb = 8;
                            timeb += UARTdelay;
                        }else{
                            stateb = 10;
                            timeb += UARTdelay/3;
                        }
                        break;
#pragma fallthrough
                    case 8:
                        byteb = 0;
                    case 7:
                    case 6:
                    case 5:
                    case 4:
                    case 3:
                    case 2:
                    case 1:
                        byteb |= (valueb << (8 - stateb));
                        stateb--;
                        timeb+=UARTdelay;
                        break;
                    case 0:
                        if(valueb == 1){//stop bit validated
                            stateb = 10;
                            timeb += UARTdelay/3;
                            //rxb <: byteb;
                            if(NEXT(endb) != startb) {
                                bufferb[endb] = byteb;
                                endb = NEXT(endb);
                            }
                        }else{
                            stateb = 10;
                            timeb += UARTdelay/3;
                        }
                        break;
                }
                break;

            // ARDUINO ////////////////////////////////////////////////////////
            case arduino_timer when timerafter(arduino_time) :> arduino_time:
                    ARDUINO :> arduino_value;
                    switch(arduino_state){
                        case 10:
                            if(arduino_value == 0){ //valid start bit detected
                                arduino_state = 9;
                                arduino_time += arduinoUARTdelay/3;
                            }else{
                                arduino_time += arduinoUARTdelay/3;
                            }
                            break;
                        case 9:
                            if(arduino_value == 0){  //start bit validated
                                arduino_state = 8;
                                arduino_time += arduinoUARTdelay;
                            }else{
                                arduino_state = 10;
                                arduino_time += arduinoUARTdelay/3;
                            }
                            break;
    #pragma fallthrough
                        case 8:
                            arduino_byte = 0;
                        case 7:
                        case 6:
                        case 5:
                        case 4:
                        case 3:
                        case 2:
                        case 1:
                            arduino_byte |= (arduino_value << (8 - arduino_state));
                            arduino_state--;
                            arduino_time+=arduinoUARTdelay;
                            break;
                        case 0:
                            if(arduino_value == 1){//stop bit validated
                                arduino_state = 10;
                                arduino_time += arduinoUARTdelay/3;
                                if(NEXT(arduino_end) != arduino_start) {
                                    arduino_buffer[arduino_end] = arduino_byte;
                                    arduino_end = NEXT(arduino_end);
                                    //printf("byte: %d\n", arduino_byte);
                                }
                            }else{
                                arduino_state = 10;
                                arduino_time += arduinoUARTdelay/3;
                            }
                            break;
                    }
                    break;

                // THE INTERFACES ! //////////////////////////////////////////////////

            case reader.clear():
                starta = enda = 0;
                startb = endb = 0;
                break;

                // camera a
            case reader.avalible_a() -> int return_val:
                if(starta != enda) {
                    return_val = fifo_length(starta, enda);
                } else {
                    return_val = 0;
                }
                break;
            case reader.getc_a() -> char c:
                if(starta != enda) {
                    c = buffera[starta];
                    starta = NEXT(starta);
                } else {
                    c = -1;
                }
                break;
            case reader.geti_a() -> int i:
                if(fifo_length(starta, enda) >= 2) {
                    i = buffera[starta];
                    starta = NEXT(starta);
                    i |= buffera[starta] << 8;
                    starta = NEXT(starta);
                } else {
                    i = -1;
                }
                break;

                // camera b
            case reader.avalible_b() -> int return_val:
                if(startb != endb) {
                    return_val = fifo_length(startb, endb);
                } else {
                    return_val = 0;
                }
                break;
            case reader.getc_b() -> char c:
                if(startb != endb) {
                    c = bufferb[startb];
                    startb = NEXT(startb);
                } else {
                    c = -1;
                }
                break;
            case reader.geti_b() -> int i:
                if(fifo_length(startb, endb) >= 2) {
                    i = bufferb[startb];
                    startb = NEXT(startb);
                    i |= bufferb[startb] << 8;
                    startb = NEXT(startb);
                } else {
                    i = -1;
                }
                break;

            // arduino interface
            case arduino.clear():
                arduino_start = arduino_end = 0;
                break;
            case arduino.avalible() -> int return_val:
                if(arduino_start != arduino_end) {
                    return_val = fifo_length(arduino_start, arduino_end);
                } else {
                    return_val = 0;
                }
                break;
            case arduino.geti() -> int i:
                if(fifo_length(arduino_start, arduino_end) >= 2) {
                    i = arduino_buffer[arduino_start];
                    arduino_start = NEXT(arduino_start);
                    i |= arduino_buffer[arduino_start] << 8;
                    arduino_start = NEXT(arduino_start);
                    if(i & 0b1000000000000000) {
                        // negative
                        i |= (0b1111111111111111<<16); // make it all 1s in the front (2s complement form negative)
                    }
                } else {
                    i = -1;
                }
                break;
        }
    }
}

void uart_test(interface uart_int client rx) {
    rx.clear();
    while(1) {
        //printf("bufferd characters: %d\n", rx.avalible_a());

        if(rx.avalible_a() >= 19) {
            for(int i = 0; i < 19; i++) {
                char c = rx.getc_a();
                printf("%c",c,(int)c);
            }
            printf("\n");
        }

        delay(1e8);
    }
}
