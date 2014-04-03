/*
 * MovementControl.xc
 *
 *  Created on: Apr 2, 2014
 *      Author: rdbeethe
 */

#include "MovementControl.h"



void goForwards(int distance,chanend MOTORCONTROLLER,out port DEBUGTX){
    char buffer[80];
    int distanceTraveled = 0;
    int previousDistance;
    int integral = 0;
    int speed = 0;
    int power;
    int p;
    int i;
    int d;
    timer t;
    int time;
    t :> time;

    MOTORCONTROLLER <: 3; //reset encoders;
    MOTORCONTROLLER <: 7; //set both sides power;
    MOTORCONTROLLER <: 40; //this is the power setting



    while(distanceTraveled < distance){
        t when timerafter(time) :> time;
        previousDistance = distanceTraveled;
        distanceTraveled = getSmallestEncoderChange(MOTORCONTROLLER);

        speed = (6*speed+100*(distanceTraveled-previousDistance))/7; //we increase the incremental distance by 100 to have better resolution for the speed;

        if(speed > integralThreshold && integral > 0){
            integral--;
        }else{
            integral++;
        }

        if(distance - distanceTraveled > proportionalZone){
            power = maxNaturalPower;
        }else{
            power = (distance -distanceTraveled)*maxNaturalPower / proportionalZone; //set power to proportional value;
        }
        p = power;

        power -= speed*derivativeCorrection; //lower the power a little to dampen the system;
        d = -speed*derivativeCorrection;

        power += integral*integralCorrection; //raise the power a little continously to prevent it from stopping early;
        i = integral*integralCorrection;

        if(power >100){
            power = 100;
        }else if(power <0){
            power = 0;
        }
        MOTORCONTROLLER <: 7; //set both sides power;
        MOTORCONTROLLER <: power; //this is the power setting
        sprintf(buffer,"power: %d\t speed: %d\tintegral: %d\tdistance: %d\t p: %d\t i: %d\td: %d\n",power,speed,integral,distanceTraveled,p,i,d);
        tx_str(DEBUGTX, buffer);


        time += 2e5;
    }
    //distance has been reached, while() loop is complete

    MOTORCONTROLLER <: 7; //set both sides power
    MOTORCONTROLLER <: 0;
    monitorEncoders(MOTORCONTROLLER, DEBUGTX);

    t :> time;
    time += 1e8;
    t when timerafter(time) :> time;
    tx_str(DEBUGTX, "after complete stop:\n");
    monitorEncoders(MOTORCONTROLLER, DEBUGTX);
}

void monitorEncoders(chanend MOTORCONTROLLER,out port DEBUGTX){
    int encoders[4] = {0,0,0,0};
    char buffer[80];
    MOTORCONTROLLER <: 4; //get encoder values;
    MOTORCONTROLLER :> encoders[0];
    MOTORCONTROLLER :> encoders[1];
    MOTORCONTROLLER :> encoders[2];
    MOTORCONTROLLER :> encoders[3];
    sprintf(buffer,"LF: %d LB: %d RF: %d RB: %d\n", encoders[0],encoders[1],encoders[2],encoders[3]);
    tx_str(DEBUGTX, buffer);
}

int getSmallestEncoderChange(chanend MOTORCONTROLLER){ //this returns the smallest encoder value since the last reset
    int encoders[4];

    MOTORCONTROLLER <: 4; //get encoder values;
    MOTORCONTROLLER :> encoders[0];
    MOTORCONTROLLER :> encoders[1];
    MOTORCONTROLLER :> encoders[2];
    MOTORCONTROLLER :> encoders[3];

    if(encoders[0] <= encoders[1]){ //get smallest encoder value, set it to distanceTraveled
        if(encoders[0] <= encoders[2]){
            if(encoders[0] <= encoders[3]){
                return encoders[0];
            }else{
                return encoders[3];
            }
        }else if(encoders[2] <= encoders[3]){
            return encoders[2];
        }else{
            return encoders[3];
        }
    }else if(encoders[1] <= encoders[2]){
        if(encoders[1] <= encoders[3]){
            return encoders[1];
        }else{
            return encoders[3];
        }
    }else if(encoders[2] <= encoders[3]){
        return encoders[2];
    }else{
        return encoders[3];
    }
}



