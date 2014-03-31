/*
 * line_tester.xc
 *
 *  Created on: Mar 30, 2014
 *      Author: tylerjw
 */

#include "stdio.h"
#include "LineMatcher.h"

int line_matcher_test_thread(){
    vector a;
    vector b;
    vector testa;
    vector testb;
    testResult r;
    int vectora[2] = {363,261};
    int vectorb[2] = {259,282};
    vector_init(a, vectora,0);
    vector_init(b, vectorb,1);
    testa.x = -169;
    testa.y = -1;
    testa.z = -241;

    testb.x = -1;
    testb.y = -171;
    testb.z = -239;

    timer t;
    int start, end;

    long long togetherness;
    long long normalDistance;

    printf("init 80 test\n");

    t :> start;

    for(int i = 0; i < 40; i++ ) {
        vector_init(a, vectora,0);
        vector_init(b, vectorb,1);
    }

    t :> end;

    printf("End: %d, Start %d\n", end, start);
    int ms = (end - start) / 1e5;
    printf("took : %d ms\n", ms);

    t :> start;

    for(int i = 0; i < (40*40); i++) {

        //first test togetherness to determine if the vectors point towards or away from each other.
        //if the togetherness value is negative, then there is no need to continue.
        togetherness = vector_togetherness(a, b, r);

        //check for parallel vectors (occurs when normal vector magnitued = 0)
        if(r.n_magnitude == 0){printf("oh no! the vectors are parallel!");}

        //then test for the actual normal distance between the two vectors
        normalDistance = vector_normalDistance(a, b, r);

        //if you determine that the two vectors represent two images of the same dot,
        //get the coordinates of the points nearest to an intersection.
        //*********THIS STEP STILL HAS A COMMON MULTIPLE BETWEEN THE NUM AND DENOM
        vector_getTargetPoint(a, b, r);
    }
    t :> end;

    printf("End: %d, Start %d\n", end, start);
    ms = (end - start) / 1e5;
    printf("Calculation (40x40) took : %d ms\n", ms);

    printf("togetherness = %lld\tnormal distance = %lld\n",togetherness,normalDistance);

    //test manual values
    printf("\nManually entered values:\n");
    togetherness = vector_togetherness(testa, testb, r);
    normalDistance = vector_normalDistance(testa, testb, r);
    vector_getTargetPoint(testa, testb, r);
    printf("togetherness = %lld\tnormal distance = %lld\n",togetherness,normalDistance);

    return 0;
}
