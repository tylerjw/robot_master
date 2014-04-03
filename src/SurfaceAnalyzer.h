/*
 * SurfaceAnalyzer.h
 *
 *  Created on: Jan 13, 2014
 *      Author: rdbeethe
 */

#ifndef SURFACEANALYZER_H_
#define SURFACEANALYZER_H_

#include <stdio.h>

#ifndef LINEMATCHER_H_
//we can use the same vector struct as before
struct {
	int x;
	int y;
	int z;
} typedef vector;

#endif //LINEMATCHER_H_


/////////////////////////////////////////////////////////////////


#ifdef __XC__

void analyzeAll();
int analyzePoints(vector &a, vector &b);
void defineMeasurments();
void setVector(vector &v, int x, int y, int z);
long long rootEstimation(long long originalNumber);

#else  //c, not xc////////////////////

void analyzeAll();
int analyzePoints(vector* a, vector* b);
void defineMeasurments();
void setVector(vector* v, int x, int y, int z);
long long rootEstimation(long long originalNumber);

#endif//xc

////////////////////////////////////////////////////////////////////


#endif //SURFACEANALYZER_H_
