/*
 * MovementControl.h
 *
 *  Created on: Apr 2, 2014
 *      Author: rdbeethe
 */

#ifndef MOVEMENTCONTROL_H_
#define MOVEMENTCONTROL_H_

#include "uart.h"
#include <stdio.h>
#include "xs1.h"
#include "platform.h"

#define proportionalZone 500
#define derivativeCorrection 30/100
#define integralCorrection 20/100
#define integralThreshold 50
#define maxNaturalPower 100



void movementControl_init(out port txport, chanend motorControllerChanend);
void goForwards(int distance,chanend MOTORCONTROLLER,out port DEBUGTX);
void monitorEncoders(chanend MOTORCONTROLLER,out port DEBUGTX);
int getSmallestEncoderChange(chanend MOTORCONTROLLER);




#endif /* MOVEMENTCONTROL_H_ */
