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

#define RX_BUF_SIZE          100
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
    int getc_a();
    int getc_b();
};

void clearRXchannels(chanend rxa, chanend rxb){
    int value;
    select{
        case rxa :> value:
            break;
        default:
            break;
    }
    select{
        case rxb :> value:
            break;
        default:
            break;
    }
}

void wait_for_continue(chanend rxa, chanend rxb) {
    int ca = 1,
        cb = 1;

    while(ca != 0 && cb != 0) {
        select {
            case rxa :> ca:
                break;
            case rxb :> cb:
                break;
            default:
                break;
        }
    }
}

int uart_getc(chanend rx) {
    int c;
    rx :> c;
    return c;
}

int uart_geti(chanend rx) {
    int c, r;
    rx :> c;
    r = c;
    rx :> c;
    r |= c << 8;
    return r;
}

void button_control(interface uart_int client rx) {
//    int num_points_a;
//    int num_points_b;
//    int num_columns_a;
//    int num_rows_b;
//
//    int points_a[POINT_BUFFER_LENGTH][2];
//    int points_b[POINT_BUFFER_LENGTH][2];
//    int col_idx[MAX_COLUMNS];
//    int row_idx[MAX_ROWS];

    LEDS <: 0;
    while(1) {
        select {
        case BUTTON1 when pinseq(0) :> void:
            //delay(20e6); // debounce
#ifdef DEBUG
            printf("Button 1 pressed\n");
#endif
            //laser.laser_on();
            LASER <: 1;
            rx.clear();
            tx(TX, CAPTURE_DOTS);
            while(rx.getc_a() != 0) delay(1e6);
            while(rx.getc_b() != 0) delay(1e6);
            LASER <: 0;
            BUTTON1 when pinseq(1) :> void;
            delay(20e6); // debounce
            printf("took the forst picture\n");
            break;


        case BUTTON2 when pinseq(0) :> void:
            //delay(20e6); // debounce
#ifdef DEBUG
            printf("Button 2 pressed\n");
#endif
            rx.clear();
            tx(TX, CAPTURE_NORM);
            while(!rx.avalible_a() && rx.getc_a() != 0);
            while(!rx.avalible_b() && rx.getc_b() != 0);
#ifdef DEBUG
            printf("Captured no dots...\n");
#endif
            /*
            clearRXchannels(rxa,rxb);
            tx(TX, READ_A);
            num_points_a = uart_geti(rxa);
            num_columns_a = uart_geti(rxa);
            // get the points
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                points_a[i][0] = uart_geti(rxa);
                points_a[i][1] = uart_geti(rxa);
            }
            for(int i = 0; i < num_columns_a && i < MAX_COLUMNS; i++) {
                col_idx[i] = uart_geti(rxa);
            }
            LEDS <: 1;
#ifdef DEBUG
            printf("num_points_a: %d, num_columns: %d\n", num_points_a, num_columns_a);
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                printf("(%d, %d)\n", points_a[i][0], points_a[i][1]);
            }
#endif

            tx(TX, READ_B);
            num_points_b = uart_geti(rxb);
            num_rows_b = uart_geti(rxb);
            // get the points
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                points_b[i][0] = uart_geti(rxb);
                points_b[i][1] = uart_geti(rxb);
            }
            for(int i = 0; i < num_rows_b && i < MAX_ROWS; i++) {
                row_idx[i] = uart_geti(rxb);
            }
            LEDS <: 2;
#ifdef DEBUG
            printf("num_points_b: %d, num_rows: %d\n", num_points_b, num_rows_b);
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                printf("(%d, %d)\n", points_b[i][0], points_b[i][1]);
            }
#endif
            */
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

void multiRX(interface uart_int server reader, in port RXA, in port RXB){
    timer timera;
    timer timerb;
    int timea;
    int timeb;
    int valuea;
    int valueb;
    int bytea;
    int byteb;
    int statea = 10; //10=wating for start bit, 9=checking valid start bit, (1-8)=# of bits left, 0=checking end bit
    int stateb = 10;
    int UARTdelay = 10417;//baud rate = 9600
    timera :> timea;
    timerb :> timeb;

    int buffera[RX_BUF_SIZE];
    int starta = 0;
    int enda = 0;
    int bufferb[RX_BUF_SIZE];
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
                        bytea <<1;
                        bytea += valuea;
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
                                printf("bufffera[%d] : %d\n", enda, buffera[enda]);
                                enda = NEXT(enda); // advance the end
                                printf("enda: %d\n", enda);
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
                        byteb <<1;
                        byteb += valueb;
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
                                printf("buffferb[%d] : %d\n", endb, bufferb[endb]);
                                endb = NEXT(endb);
                                printf("endb: %d\n", endb);
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
                if(starta != enda)
                    return_val = 1;
                else
                    return_val = 0;
                break;
            case reader.getc_a() -> int c:
                if(starta != enda) {
                    c = buffera[starta];
                    starta = NEXT(starta);
                    printf("getc_a: %d\n", c);
                } else {
                    c = -1;
                }
                break;

                // camera b
            case reader.avalible_b() -> int return_val:
                if(startb != endb)
                    return_val = 1;
                else
                    return_val = 0;
                break;
            case reader.getc_b() -> int c:
                if(startb != endb) {
                    c = bufferb[startb];
                    startb = NEXT(startb);
                    printf("getc_b: %d\n", c);
                } else {
                    c = -1;
                }
                break;
        }
    }
}

int main(void) {
    interface uart_int rx_int;
    par {
        on tile[0]:button_control(rx_int);
        on tile[0]:multiRX(rx_int,RXA,RXB);
    }
    return 0;
}
