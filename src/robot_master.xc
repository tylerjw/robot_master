/*
 * robot_master.xc
 *
 *  Created on: Mar 18, 2014
 *      Author: tylerjw
 */
#include <uart.h>
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <string.h>


out port LEDS = on tile[0]:XS1_PORT_4F;

in port BUTTON1 = on tile[0]:XS1_PORT_1K;
in port BUTTON2 = on tile[0]:XS1_PORT_1L;

in port RXB = on tile[0]:XS1_PORT_1E;
in port RXA = on tile[0]:XS1_PORT_1F;
out port TX = on tile[0]:XS1_PORT_4C;

out port DEBUGTX = on tile[0]:XS1_PORT_1D;
in port DEBUGRX = on tile[0]:XS1_PORT_1C;

out port LASER = on tile[0]:XS1_PORT_1B;

void delay(int delay){
    timer t;
    int time;
    t :> time;
    time += delay;
    t when timerafter(time) :> void;
}

#define CAPTURE_DOTS    '0'
#define CAPTURE_NORM    '1'
#define READ_A          '2'
#define READ_B          '3'

#define POINT_BUFFER_LENGTH   300
#define MAX_COLUMNS           30
#define MAX_ROWS              30

#define RX_BUF_SIZE          500
#define NEXT(x)              ((x+1)%RX_BUF_SIZE)

#define START           0b00
#define DONE            0b11

#define DEBUG

interface laser_int {
    void laser_on();
    void laser_off();
};

interface uart_int {
    void clear();
    int avalible_a();
    int avalible_b();
    char getc_a();
    char getc_b();
    int geti_a();
    int geti_b();
};

int watchdog_timer(int init, int d) {
    static int base;
    int time;
    const int timeout = 2e8; // 2 second timeout
    timer t;
    delay(d);
    if (init) {
        t :> base;
    } else {
        t :> time;
        if((time - base) > timeout) {
            return 1;
        }
    }
    return 0;
}

void button_control(interface uart_int client rx) {
    int num_points_a;
    int num_points_b;
    int num_columns_a;
    int num_rows_b;

    int points_a[POINT_BUFFER_LENGTH][2];
    int points_b[POINT_BUFFER_LENGTH][2];
    int col_idx[MAX_COLUMNS];
    int row_idx[MAX_ROWS];

    LEDS <: 0;
    while(1) {
        select {
        case BUTTON1 when pinseq(0) :> void:
            watchdog_timer(1,0); // init watchdog
#ifdef DEBUG
            printf("Button 1 pressed\n");
#endif
            //laser.laser_on();
            LASER <: 1;
            rx.clear();
            tx(TX, CAPTURE_DOTS);
            while(rx.getc_a() != 0)
                if(watchdog_timer(0,1e6))
                    break;
            while(rx.getc_b() != 0)
                if(watchdog_timer(0,1e6))
                    break;
            LASER <: 0;
            BUTTON1 when pinseq(1) :> void;

#ifdef DEBUG
            printf("took the forst picture\n");
#endif
            break;


        case BUTTON2 when pinseq(0) :> void:
            watchdog_timer(1,0); // init watchdog
#ifdef DEBUG
            printf("Button 2 pressed\n");
#endif
            rx.clear();
            tx(TX, CAPTURE_NORM);
            while(rx.getc_a() != 0)
                if(watchdog_timer(0,1e6))
                    break;
            while(rx.getc_b() != 0)
                if(watchdog_timer(0,1e6))
                    break;
#ifdef DEBUG
            printf("Captured no dots...\n");
#endif

            rx.clear();
            tx(TX, READ_A);
            while(rx.avalible_a() < 4)
                if(watchdog_timer(0,1e6))
                    break;
            num_points_a = rx.geti_a();
            num_columns_a = rx.geti_a();

#ifdef DEBUG
            printf("got the number of points and columns\n");
#endif
            // get the points
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                while(rx.avalible_a() < 4)
                    if(watchdog_timer(0,1e6))
                        break;
                points_a[i][0] = rx.geti_a();
                points_a[i][1] = rx.geti_a();
            }
            for(int i = 0; i < num_columns_a && i < MAX_COLUMNS; i++) {
                while(rx.avalible_a() < 2)
                    if(watchdog_timer(0,1e6))
                        break;
                col_idx[i] = rx.geti_a();
            }
            LEDS <: 1;
#ifdef DEBUG
            printf("num_points_a: %d, num_columns: %d\n", num_points_a, num_columns_a);
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                printf("(%d, %d)\n", points_a[i][0], points_a[i][1]);
            }
#endif

            tx(TX, READ_B);
            while(rx.avalible_b() < 4)
                if(watchdog_timer(0,1e6))
                    break;
            num_points_b = rx.geti_b();
            num_rows_b = rx.geti_b();

            // get the points
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                while(rx.avalible_b() < 4)
                    if(watchdog_timer(0,1e6))
                        break;
                points_b[i][0] = rx.geti_b();
                points_b[i][1] = rx.geti_b();
            }
            for(int i = 0; i < num_rows_b && i < MAX_ROWS; i++) {
                while(rx.avalible_b() < 2)
                    if(watchdog_timer(0,1e6))
                        break;
                row_idx[i] = rx.geti_b();
            }
            LEDS <: 2;
#ifdef DEBUG
            printf("num_points_b: %d, num_rows: %d\n", num_points_b, num_rows_b);
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                printf("(%d, %d)\n", points_b[i][0], points_b[i][1]);
            }
#endif
            BUTTON2 when pinseq(1) :> void;

            break;
        }
    }
}

void uart_rx_thread(streaming chanend rx_chan, in port rx_port) {
    int c;
    while(1) {
        c = rx(rx_port);
        //printf("rx: %d\n", c);
        rx_chan <: c;
    }
}

void pwm_laser_thread(interface laser_int server from_button) {
    int laser_on = 0;
    int laser_state = 0;
    timer t;
    int time;

    int Laser_PWM_period = 1e6;
    int PWM_dutyCycle = 80;

    t :> time;

    while(1) {
        if(laser_state == 0) {
            time += Laser_PWM_period/100*(100-PWM_dutyCycle);
        } else {
            time += Laser_PWM_period/100*PWM_dutyCycle;
        }
        time += Laser_PWM_period/100*PWM_dutyCycle;
        select {
            case from_button.laser_on():
                laser_on = 1;
                break;
            case from_button.laser_off():
                laser_on = 0;
                break;
            case t when timerafter(time) :> void :
                if(laser_state == 1) {
                    LASER <: 0;
                    laser_state = 0;
                } else if(laser_on == 1 && laser_state == 0) {
                    LASER <: 1;
                    laser_state = 1;
                }
                break;
        }
    }
}

int fifo_length(int start, int end) {
    if(end == start) {
        return 0;
    } else if(end > start) {
        return end - start;
    }
    return (RX_BUF_SIZE - start) + end;
}

void multiRX(interface uart_int server reader, in port RXA, in port RXB){
    timer timera;
    timer timerb;
    int timea;
    int timeb;
    char valuea;
    char valueb;
    char bytea;
    char byteb;
    int statea = 10; //10=wating for start bit, 9=checking valid start bit, (1-8)=# of bits left, 0=checking end bit
    int stateb = 10;
    int UARTdelay = 10417;//baud rate = 9600
    timera :> timea;
    timerb :> timeb;

    char buffera[RX_BUF_SIZE];
    int starta = 0;
    int enda = 0;
    char bufferb[RX_BUF_SIZE];
    int startb = 0;
    int endb = 0;

    while(1){
        select{
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
                                printf("bytea: %c - %d\n", bytea, bytea);
                                LEDS <: bytea;
                                enda = NEXT(enda); // advance the end
                            }
                        }else{
                            statea = 10;
                            timea += UARTdelay/3;
                        }
                        break;
                }
                break;

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
                                //printf("byteb: %c - %d\n", byteb, byteb);
                                endb = NEXT(endb);
                            }
                        }else{
                            stateb = 10;
                            timeb += UARTdelay/3;
                        }
                        break;
                }
                break;


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
        }
    }
}

void uart_test(interface uart_int client rx) {
    rx.clear();
    while(1) {
        if(rx.avalible_a() >= 10) {
            for(int i = 0; i < 10; i++) {
                char c = rx.getc_a();
                printf("%c (%d),",c,(int)c);
            }
            printf("\n");
        }
        delay(1e8);
    }
}

int main(void) {
    interface uart_int rx_int;
    par {
        on tile[0]:uart_test(rx_int);
        on tile[0]:multiRX(rx_int,DEBUGRX,RXB);
    }
    return 0;
}
