/*
 * motorController.xc
 *
 *  Created on: Feb 28, 2014
 *      Author: rdbeethe
 */
#include "motorController.h"
#include <platform.h>
#include <xs1.h>

int leftsideValue = 0;
int leftsideDirection = 0;
int forwardsBackwardsReading = 0;
int oldLeftsideDirection = 0;
int oldLeftsideValue = 0;
int rightsideValue = 0;
int rightsideDirection = 0;
int turningReading = 0;
int oldRightsideDirection = 0;
int oldRightsideValue = 0;
int turningValue = 0;
int turningDirection = 0;
int brakingValue;
long lastTime = 0;
long leftsideDelayTime = 0;
long rightsideDelayTime = 0;
long nextChangeDelayTime = 0;


int LF_encoderCount = 0;
int LB_encoderCount = 0;
int RF_encoderCount = 0;
int RB_encoderCount = 0;

void motorControllerThread(chanend control, out port motorPort, in port encoderPort, out port LEDport){
    int input;

    int L_PWMtime;
    int R_PWMtime;
    timer L_PWMtimer;
    timer R_PWMtimer;
    char L_PWMcounter = 0; //starts at 0 so PWM starts with turning on
    char R_PWMcounter = 0; //starts at 0 so PWM starts with turning on
    int L_PWMpower = 0;
    int R_PWMpower = 0;
    int L_PWMtimeOff;
    int R_PWMtimeOff;
    int motorSetting = 0;
    int L_brake = 0;
    int R_brake = 0;

    int encoderTime;
    timer encoderTimer;
    int lastEncoderReading;
    int encoderReading;
//    int LF_encoderCount = 0; //these became global variables
//    int LB_encoderCount = 0;
//    int RF_encoderCount = 0;
//    int RB_encoderCount = 0;

    motorPort <: motorSetting; //starts with motors off
    L_PWMtimer :> L_PWMtime;
    R_PWMtimer :> R_PWMtime;
    R_PWMtime += PWM_period/2; //offsets motor on times to minimize ripple current in motor controller

    encoderTimer :> encoderTime;
    encoderTime += encoderCheckTime;
    encoderPort :> lastEncoderReading;



    while(1){
        select{
            //Check for new input from control channel:
            case control :> input:
                switch(input){
                    case 1: //button 1
                        L_PWMpower -= 10;if(L_PWMpower==-110)L_PWMpower=100;break;
                    case 2: //button 2
                        R_PWMpower -= 10;if(R_PWMpower==-110)R_PWMpower=100;break;
                    case 3: //reset encoders
                        resetEncoders(); break;
                    case 4: //output encoder values
                        control <: LF_encoderCount;
                        control <: LB_encoderCount;
                        control <: RF_encoderCount;
                        control <: RB_encoderCount;
                        break;
                    case 5: //change leftside power
                        control :> L_PWMpower; L_brake = 0; break;
                    case 6: //change rightside power
                        control :> R_PWMpower; R_brake = 0; break;
                    case 7: //change both sides power
                        control :> L_PWMpower; R_PWMpower = L_PWMpower;
                        L_brake = 0; R_brake = 0; break;
                    case 8: //make leftside brake
                        control :> L_PWMpower; L_brake = 1; break;
                    case 9: //make rightside brake
                        control :> R_PWMpower; R_brake = 1; break;
                    case 10: //make both sides brake
                        control :> L_PWMpower; R_PWMpower = L_PWMpower;
                        L_brake = 1; R_brake = 1; break;
                    }
                break;

            //Check encoders
            case encoderTimer when timerafter(encoderTime) :> encoderTime: //time to poll the encoders
                encoderTime += encoderCheckTime;
                encoderPort :> encoderReading;
                if(encoderReading != lastEncoderReading){ //one or more encoders has changed
                    if((encoderReading&LF_encoderMask) != (lastEncoderReading&LF_encoderMask)){
                        LF_encoderCount++;
                    }
                    if((encoderReading&LB_encoderMask) != (lastEncoderReading&LB_encoderMask)){
                        LB_encoderCount++;
                    }
                    if((encoderReading&RF_encoderMask) != (lastEncoderReading&RF_encoderMask)){
                        RF_encoderCount++;
                    }
                    if((encoderReading&RB_encoderMask) != (lastEncoderReading&RB_encoderMask)){
                        RB_encoderCount++;
                    }
                    lastEncoderReading = encoderReading; //save this reading as the lastEncoderReading for comparison
                }

//                LEDport <: encoderReading;
//                printf("encoder reading: %d\n",encoderReading);
                break;

            //check PWM leftSide
            case L_PWMtimer when timerafter(L_PWMtime) :> L_PWMtime:
                switch(L_PWMcounter){
                    case 0: //motor needs to be turned on
                        if(L_PWMpower == 100){// motor needs to stay on, counter stays at 0, motor may be braking
                            if(L_brake == 0){
                                motorSetting = (motorSetting & leftOff) | leftForwards ;//just to make sure we don't short anything
                            }else{
                                motorSetting = (motorSetting & leftOff) | leftBrake ;//just to make sure we don't short anything
                            }
                            L_PWMtime += PWM_period;
                        }else if(L_PWMpower == -100){// motor needs to stay on
                            motorSetting = (motorSetting & leftOff) | leftBackwards ;//just to make sure we don't short anything
                            L_PWMtime += PWM_period;
                        }else if(L_PWMpower > 0){//motor is moving forwards, motor may be braking
                            if(L_brake == 0){
                                motorSetting = (motorSetting & leftOff) | leftForwards ;//just to make sure we don't short anything
                            }else{
                                motorSetting = (motorSetting & leftOff) | leftBrake ;//just to make sure we don't short anything
                            }
                            L_PWMtimeOff = L_PWMtime + PWM_period;
                            L_PWMtime += PWM_period/100*L_PWMpower;
                            L_PWMcounter = 1;
                        }else if(L_PWMpower < 0){//motor is moving backwards
                            motorSetting = (motorSetting & leftOff) | leftBackwards ;//just to make sure we don't short anything
                            L_PWMtimeOff = L_PWMtime + PWM_period;
                            L_PWMtime -= PWM_period/100*L_PWMpower;
                            L_PWMcounter = 1;
                        }else{//motor is set to 0 power, counter stays at 0
                            L_PWMtime += PWM_period;
                            motorSetting &= leftOff;
                        }
                        break;
                    case 1: //motor needs to be turned off
                        motorSetting &= leftOff;
                        L_PWMtime = L_PWMtimeOff;
                        L_PWMcounter = 0;
                        break;
                }
                motorPort <: motorSetting;
//                printf("\n");
                break;

                //check PWM rightSide
                case R_PWMtimer when timerafter(R_PWMtime) :> void:
                    R_PWMtimer :> R_PWMtime;//get current time
                    switch(R_PWMcounter){
                        case 0: //motor needs to be turned on
                            if(R_PWMpower == 100){// motor needs to stay on, counter stays at 0, motor may be braking
                                if(R_brake == 0){
                                    motorSetting = (motorSetting & rightOff) | rightForwards ;//just to make sure we don't short anything
                                }else{
                                    motorSetting = (motorSetting & rightOff) | rightBrake ;//just to make sure we don't short anything
                                }
                                R_PWMtime += PWM_period;
                            }else if(R_PWMpower == -100){// motor needs to stay on
                                motorSetting = (motorSetting & rightOff) | rightBackwards ;//just to make sure we don't short anything
                                R_PWMtime += PWM_period;
                            }else if(R_PWMpower > 0){//motor is moving forwards, motor may be braking
                                if(R_brake == 0){
                                    motorSetting = (motorSetting & rightOff) | rightForwards ;//just to make sure we don't short anything
                                }else{
                                    motorSetting = (motorSetting & rightOff) | rightBrake ;//just to make sure we don't short anything
                                }
                                R_PWMtimeOff = R_PWMtime + PWM_period;
                                R_PWMtime += PWM_period/100*R_PWMpower;
                                R_PWMcounter = 1;
                            }else if(R_PWMpower < 0){//motor is moving backwards
                                motorSetting = (motorSetting & rightOff) | rightBackwards ;//just to make sure we don't short anything
                                R_PWMtimeOff = R_PWMtime + PWM_period;
                                R_PWMtime -= PWM_period/100*R_PWMpower;
                                R_PWMcounter = 1;
                            }else{//motor is set to 0 power, counter stays at 0
                                R_PWMtime += PWM_period;
                                motorSetting &= rightOff;
                            }
                            break;
                        case 1: //motor needs to be turned off
                            motorSetting &= rightOff;
                            R_PWMtime = R_PWMtimeOff;
                            R_PWMcounter = 0;
//                            printf("l");
                            break;
                    }
                    motorPort <: motorSetting;
//                    printf("\n");
                    break;
        }
    }
}

void resetEncoders(){
    RF_encoderCount = 0;
    RB_encoderCount = 0;
    LF_encoderCount = 0;
    LB_encoderCount = 0;
}

//old loop function
void setSpeedController(int tspeed, int tturn){
  if(millis()>nextChangeDelayTime){
  /*Serial.print("leftside = ");
  Serial.print(leftsideValue);
  Serial.print(", rightside = ");
  Serial.println(rightsideValue);*/

    renewOldValues();
    setValuesAndDirections(tspeed,tturn);
    adjustValuesAndDirections();
    checkForDirectionSwitches();
    filterSuddenChanges();
    setMotorSignals(-1); //-1 signifies a normal braking constant
    identifyStops();
    nextChangeDelayTime = millis() + delayBetweenChanges;
  }
}

//modified setSpeedController function: adjusts motor values instantly without regard to nextChangeDelayTime or maxChange.
void setSpeedControllerWithOverride(int tspeed, int tturn, int tbrake){ //set tbrake = -1 for normal braking behavior.

  renewOldValues();
  setValuesAndDirections(tspeed,tturn);
  adjustValuesAndDirections();
  setMotorSignals(tbrake);  //known bug: this does not override stop delay on individual motors
  identifyStops();

  nextChangeDelayTime = millis() + delayBetweenChanges;

}

void renewOldValues(){
  oldLeftsideDirection=leftsideDirection;  //records old leftsideDirection for the purposes of comparing to the new one
  oldLeftsideValue=leftsideValue;   //records old leftsideValue for the purposes of more gradual changes
  oldRightsideDirection=rightsideDirection;  //records old rightsideDirection for the purposes of comparing to the new one
  oldRightsideValue=rightsideValue;   //records old rightsideValue for the purposes of more gradual changes
}


void setValuesAndDirections(int ttspeed, int ttturn){

    turningValue = -ttturn;       //lego motors are hooked up backwards...
    rightsideValue = -ttspeed;    //lego motors are hooked up backwards...
    leftsideValue = -ttspeed;     //lego motors are hooked up backwards...

    leftsideValue += turningValue;  //adds turn into motor values
    rightsideValue -= turningValue; //adds turn into motor values

}


void adjustValuesAndDirections(){
  if(leftsideValue < 0){       //leftside direction needs to be negative
    leftsideValue *= -1;
    leftsideDirection = -1;
  }else{
    if(leftsideValue>0){       //leftside direction needs to be positive
      leftsideDirection = 1;
    }else{                     //leftside direction needs to be zero
      leftsideDirection = 0;
    }
  }
  if(leftsideValue > maxValue){     //correcting for any excessive values after adding turn value to motor values
    leftsideValue = maxValue;
  }

  if(rightsideValue < 0){      //rightside direction needs to be negative
    rightsideValue *= -1;
    rightsideDirection = -1;
  }else{
    if(rightsideValue>0){      //rightside direction needs to be positive
      rightsideDirection = 1;
    }else{                     //rightside direction needs to be zero
      rightsideDirection = 0;
    }
  }
  if(rightsideValue > maxValue){    //correcting for any excessive values after adding turn value to motor values
    rightsideValue = maxValue;
  }
}




void checkForDirectionSwitches(){
   //filter out leftside direction switches, turn them to stops;
   if(leftsideDirection == -1*oldLeftsideDirection && leftsideDirection != 0){  //checks  to see if direction switched without crossing zero
     leftsideDirection = 0;  //sets direction to zero so the propper stopping technique can be utilized
     leftsideValue = 0;  //just to be consistent
   }
   //filter out rightside direction switches, turn them to stops;
   if(rightsideDirection == -1*oldRightsideDirection && rightsideDirection != 0){  //checks  to see if direction switched without crossing zero
     rightsideDirection = 0;  //sets direction to zero so the propper stopping technique can be utilized
     rightsideValue = 0;  //just to be consistent
   }
}





void filterSuddenChanges(){
  //filter out sudden leftside changes, adjust direction so that it stays with real motor direction.
  //Serial.print("prefiltered left side = ");
  //Serial.println(leftsideValue); //prints pre-filtered value
  if(oldLeftsideValue > smallChangeThreshold){ //value is allowed to increase/decrease by larger amount
    if(leftsideValue-oldLeftsideValue>maxChange){           //value is increasing by more than maxChange
      leftsideValue=oldLeftsideValue+maxChange;
    }else{
      if(oldLeftsideValue-leftsideValue>maxChange){         //value is decreasing by more than maxChange
        leftsideValue = oldLeftsideValue-maxChange;
      }
    }
  }else{                                       //value is restricted to small changes close to stopping point.
    if(leftsideValue-oldLeftsideValue>maxSmallChange){      //value is increasing by more than maxSmallChange
      leftsideValue=oldLeftsideValue+maxSmallChange;
    }else{
      if(oldLeftsideValue-leftsideValue>maxSmallChange){    //value is decreasing by more than maxSmallChange
        leftsideValue = oldLeftsideValue-maxSmallChange;
      }
    }
  }
  if(leftsideValue>0 && oldLeftsideDirection!=0){ //the corrected leftsideValue is still positive and non-zero, unless oldDirection is zero
    leftsideDirection=oldLeftsideDirection; //shows that motor has not yet come to stop or switched directions
  }
  //Serial.print("filtered left side = ");
  //Serial.println(leftsideValue); //prints post-filter value

  //filter out sudden rightside changes, adjust direction so that it stays with real motor direction.
  //Serial.println(rightsideValue); //prints pre-filtered value
  if(oldRightsideValue > smallChangeThreshold){ //value is allowed to increase/decrease by larger amount
    if(rightsideValue-oldRightsideValue>maxChange){          //value is increasing by more than maxChange
      rightsideValue=oldRightsideValue+maxChange;
    }else{
      if(oldRightsideValue-rightsideValue>maxChange){        //value is decreasing by more than maxChange
        rightsideValue = oldRightsideValue-maxChange;
      }
    }
  }else{                                       //value is restricted to small changes close to stopping point.
    if(rightsideValue-oldRightsideValue>maxSmallChange){     //value is increasing by more than maxSmallChange
      rightsideValue=oldRightsideValue+maxSmallChange;
    }else{
      if(oldRightsideValue-rightsideValue>maxSmallChange){   //value is decreasing by more than maxSmallChange
        rightsideValue = oldRightsideValue-maxSmallChange;
      }
    }
  }
  if(rightsideValue>0 && oldRightsideDirection!=0){ //the corrected rightsideValue is still positive and non-zero, unless oldDirection is zero
    rightsideDirection=oldRightsideDirection; //shows that motor has not yet come to stop or switched directions
  }
  //Serial.println(rightsideValue); //prints post-filter value
}







void setMotorSignals(int tbrakeAdjust){
  if(tbrakeAdjust == -1){
    brakingValue = brakingConstant;
  }else{
    brakingValue = tbrakeAdjust;
  }
  //set motor signals
  if(millis() > leftsideDelayTime){
    if(leftsideDirection == -1){
//      digitalWrite(12, LOW);
//      analogWrite(10, 0);
      delayMicroseconds(1);
//      digitalWrite(13, HIGH);
//      analogWrite(11,leftsideValue);
    }else{
      if(leftsideDirection == 1){
//        digitalWrite(13, LOW);
//        analogWrite(11, 0);
        delayMicroseconds(1);
//        digitalWrite(12, HIGH);
//        analogWrite(10,leftsideValue);
      }else{  //motor is at stop point
//        digitalWrite(13, LOW);
//        digitalWrite(12, LOW);
        delayMicroseconds(1);
//        analogWrite(11, brakingValue); //the two N channels are left open to create a resistive brake
//        analogWrite(10, brakingValue);
      }
    }
  }else{
    leftsideDirection = 0; //adjusts real leftsideDirection in case of stop delay
    leftsideValue = 0;  //adjusts real leftsideValue in case of stop delay
  }
  if(millis() > rightsideDelayTime){
    if(rightsideDirection == -1){
//      digitalWrite(7, LOW);
//      analogWrite(5, 0);
      delayMicroseconds(1);
//      analogWrite(6,rightsideValue);
//      digitalWrite(8, HIGH);
    }else{
      if(rightsideDirection == 1){
//        digitalWrite(8, LOW);
//        analogWrite(6, 0);
        delayMicroseconds(1);
//        digitalWrite(7, HIGH);
//        analogWrite(5,rightsideValue);
      }else{  //motor is at stop point
//        digitalWrite(8, LOW);
//        digitalWrite(7, LOW);
        delayMicroseconds(1);
//        analogWrite(6, brakingValue); //the two N channels are left open to create a resistive brake
//        analogWrite(5, brakingValue);
      }
    }
  }else{
    rightsideDirection = 0; //adjusts real rightsideDirection in case of stop delay
    rightsideValue = 0;  //adjusts real rightsideValue in case of stop delay
  }
}

void identifyStops(){
  if(leftsideDirection==0&&oldLeftsideDirection!=0){
    //Serial.println("leftside stop");          //joystick is in the center
    leftsideDelayTime = millis() + stopDuration;           //sets time before leftside motor can be changed again, allowing motor time to brake;
  }

  if(rightsideDirection==0&&oldRightsideDirection!=0){
    //Serial.println("rightside stop"); //joystick is in the center
    rightsideDelayTime = millis() + stopDuration;           //sets time before rightside motor can be changed again, allowing motor time to brake;
  }
}

int millis(){
    return 1;
}

void delayMicroseconds(int delay){

}

