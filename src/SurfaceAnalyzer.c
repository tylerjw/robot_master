/*
 * SurfaceAnalyzer.c
 *
 *  Created on: Jan 13, 2014
 *      Author: rdbeethe
 */

#include "SurfaceAnalyzer.h"

#define NUM_MEASURMENTS 15

vector measurments[NUM_MEASURMENTS];

void setVector(vector* v, int x, int y, int z){
	v->x = x;
	v->y = y;
	v->z = z;
}

void defineMeasurments(){
	int k = 0;
	setVector(&measurments[k],	20,		0,		-20); k++;	//a,0
	setVector(&measurments[k],	45,		0,		-20); k++;	//b,1
	setVector(&measurments[k],	75,		10,		-15); k++;	//c,2
	setVector(&measurments[k],	110,	0,		-17); k++;	//d,3
	setVector(&measurments[k],	130,	0,		-15); k++;	//e,4
	setVector(&measurments[k],	20,		0,		-75); k++;	//f,5
	setVector(&measurments[k],	70,		0,		-70); k++;	//g,6
	setVector(&measurments[k],	105,	0,		-60); k++;	//h,7
	setVector(&measurments[k],	125,	30,		-55); k++;	//i,8
	setVector(&measurments[k],	20,		10,		-110); k++;	//j,9
	setVector(&measurments[k],	80,		0,		-112); k++;	//k,10
	setVector(&measurments[k],	140,	0,		-110); k++;	//l,11
	setVector(&measurments[k],	10,		30,		-140); k++;	//m,12
	setVector(&measurments[k],	60,		30,		-145); k++;	//n,13
	setVector(&measurments[k],	140,	0,		-130); k++;	//p,14
}

int analyzePoints(vector* a, vector* b){
	//get distance before checking
	//only check if the points are closer than the size across the robot
	int dist;
	int slope;
	if(b->z - a->z < -50){
		return 2; //signifies that there is no point in continued testing
	}else{
		//get the square of the distance between the two points
		dist = (a->x - b->x)*(a->x - b->x) + (a->z - b->z) * (a->z - b->z);

		//get slope between the points, accurate to a tenth (hence the 10x multiplier)
		slope = 10 *((a->y - b->y)*(a->y - b->y)) / dist;
//		printf("dist = %d\n",dist);

		if(dist < 50*50 && slope > 10){
			return 1; //signifies that an obstacle has been identified
		}else{
			return 0; //signifies that an obstacle cannot be confirmed
		}
	}
}

void analyzeAll(){
	int keepTesting = 1;
	int test;
	int j;
	int k;
	for(k = 0; k < NUM_MEASURMENTS - 1; k++){
		printf("k = %d\n",k);
		j = k + 1;
		keepTesting = 1;
		while(keepTesting){ //this cannot test value of j directly because there has to be a way to exit this loop early if the points are uselessly far apart
			if(j < NUM_MEASURMENTS){
				test = analyzePoints(&measurments[k], &measurments[j]);
				switch(test){
					case 0: /*printf("no obstacle between %d and %d\n",k,j);*/ break; //no obstacle detected
					case 1: printf("obstacle found between %d and %d\n",k,j); break; //obstacle identified
					case 2: printf("done testing at %d and %d\n",k,j); keepTesting = 0; break; //no point in further testing
				}
				j++;
			}else{ //j >= NUM_MEASURMENTS
				keepTesting = 0; // ran out of vectors to test
			}
		}
	}
}
