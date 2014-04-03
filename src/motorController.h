/*
 * motorController.h
 *
 *  Created on: Feb 28, 2014
 *      Author: rdbeethe
 */

#ifndef MOTORCONTROLLER_H_
#define MOTORCONTROLLER_H_

#include <stdio.h>

//adjustable constants:
#define delayBetweenChanges 20        //time between allowed changes, in milliseconds
#define stopDuration 0                //time in milliseconds between when a motor stops and when it can start again
#define maxChange 10                  //maximum change in PWM output per sample time
#define maxSmallChange 3              //maximum change in PWM output near stopping point
#define smallChangeThreshold 30       //minimum value for which large PWM output changes are allowed
#define brakingConstant 30
#define maxValue 180

#define rightForwards 0b01100000  // "|" this in
#define rightBackwards 0b10010000 // "|" this in
#define rightBrake 0b10100000     // "|" this in
#define rightOff 0b00001111       // "&" this in
#define leftForwards 0b00000110   // "|" this in
#define leftBackwards 0b00001001  // "|" this in
#define leftBrake 0b00001010      // "|" this in
#define leftOff 0b11110000        // "&" this in

//#define rightForwards 0b1000  // "|" this in
//#define rightBackwards 0b0100 // "|" this in
//#define rightOff 0b0011       // "&" this in
//#define leftForwards 0b0010   // "|" this in
//#define leftBackwards 0b0001  // "|" this in
//#define leftOff 0b1100        // "&" this in

#define PWM_period ((int)1e6) //don't make this more than 1e6 or it overflows
#define encoderCheckTime ((int)5e4); //the shortest peaks on the scope are 1ms long, so read every .5ms to be safe
#define LF_encoderMask 0b1000
#define LB_encoderMask 0b0010
#define RF_encoderMask 0b0100
#define RB_encoderMask 0b0001


void SpeedControllerSetup();
void setSpeedController(int tspeed, int tturn);
void setSpeedControllerWithOverride(int tspeed, int tturn, int tbrake);
void renewOldValues();
void setValuesAndDirections(int ttspeed, int ttturn);
void adjustValuesAndDirections();
void checkForDirectionSwitches();
void filterSuddenChanges();
void setMotorSignals(int tbrakeAdjust);
void identifyStops();
void motorControllerThread(chanend control, out port motorPort, in port encoderPort, out port LEDport);
void resetEncoders();

//these functions need to be replaced:
int millis();
void delayMicroseconds(int delay);

#endif /* MOTORCONTROLLER_H_ */
