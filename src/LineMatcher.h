/*
 * LineMatcher.h
 *
 *  Created on: Nov 8, 2013
 *      Author: rdbeethe
 */

#ifndef LINEMATCHER_H_
#define LINEMATCHER_H_

#include <stdio.h>
#include "calibration.h"

struct {
    int x;
    int y;
    int z;
} typedef vector;

struct {
    vector n; // normal vector
    long long n_magnitude;
    long long distance; // normal distance between the two lines
    long long d_numerator; // numerator of d parameter, in equation at + a_0 + nd = bt + b0
    long long d_denominator; // denominator of d parameter
    long long int r_numerator; // numerator of r parameter
    long long int r_denominator; // denominator of r parameter
    long long int togetherness; // togetherness is a way to test if two vectors point towards or away from each other
    vector target; //the point measured in three dimensions
} typedef testResult;


/////////////////////////////////////////////////////////////////


#ifdef __XC__

long long rootEstimation(long long number);
void vector_init(vector &v, int points[2], int whichCamera);
void vector_print();
void vector_cross(vector &a, vector &b, vector &vout);
long long vector_magnitude(vector &v);
long long vector_togetherness(vector &a, vector &b, testResult &result);
long long vector_normalDistance(vector &a, vector &b, testResult &result);
void vector_getTargetPoint(vector &a, vector &b, testResult &result);

#else  //c, not xc////////////////////

long long rootEstimation(long long number);
void vector_init(vector* v, int* points, int whichCamera);
void vector_print();
void vector_cross(vector* a, vector* b, vector* vout);
long long vector_magnitude(vector* v);
long long vector_togetherness(vector* a, vector* b, testResult* result);
long long vector_normalDistance(vector* a, vector* b, testResult* result);
void vector_getTargetPoint(vector* a, vector* b, testResult* result);


#endif//xc

////////////////////////////////////////////////////////////////////


#endif /* LINEMATCHER_H_ */
