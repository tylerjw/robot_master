/*
 * LineMatcher.c
 *
 *  Created on: Nov 8, 2013
 *      Author: rdbeethe
 */

#include "LineMatcher.h"

#define c1 (CAMERA_B_X - CAMERA_A_X)
#define c2 (CAMERA_B_Y - CAMERA_A_Y)
#define c3 (CAMERA_B_Z - CAMERA_A_Z)

unsigned int rootEstimationTable[64] = {0, 2147483648, 1518500249, 1073741824, 759250124, 536870912, 379625062, 268435456, 189812531, 134217728, 94906265, 67108864, 47453132, 33554432, 23726566, 16777216, 11863283, 8388608, 5931641, 4194304, 2965820, 2097152, 1482910, 1048576, 741455, 524288, 370727, 262144, 185363, 131072, 92681, 65536, 46340, 32768, 23170, 16384, 11585, 8192, 5792, 4096, 2896, 2048, 1448, 1024, 724, 512, 362, 256, 181, 128, 90, 64, 45, 32, 22, 16, 11, 8, 5, 4, 2, 2, 1, 1};


void vector_init(vector* v, int* points, int whichCamera){ //points will be in terms of [x,y], with x and y being pixel values
    int x = points[0];
    int y = points[1];
    v->z = 0;
    if(whichCamera == 0){ //camera A
        v->x =    Ax_an * 1       / Ax_ad
                + Ax_bn * x       / Ax_bd
                + Ax_cn * x*x     / Ax_cd
                + Ax_dn * y       / Ax_dd
                + Ax_en * y*y     / Ax_ed
                + Ax_fn * x*y     / Ax_fd
                + Ax_gn * x*x*x   / Ax_gd
                + Ax_hn * x*x*y   / Ax_hd
                + Ax_in * x*y*y   / Ax_id
                + Ax_jn * y*y*y   / Ax_jd
                + Ax_kn * x*x*x*x / Ax_kd
                + Ax_mn * x*x*x*y / Ax_md
                + Ax_nn * x*x*y*y / Ax_nd
                + Ax_pn * x*y*y*y / Ax_pd
                + Ax_qn * y*y*y*y / Ax_qd;

        v->y =    Ay_an * 1       / Ay_ad
                + Ay_bn * x       / Ay_bd
                + Ay_cn * x*x     / Ay_cd
                + Ay_dn * y       / Ay_dd
                + Ay_en * y*y     / Ay_ed
                + Ay_fn * x*y     / Ay_fd
                + Ay_gn * x*x*x   / Ay_gd
                + Ay_hn * x*x*y   / Ay_hd
                + Ay_in * x*y*y   / Ay_id
                + Ay_jn * y*y*y   / Ay_jd
                + Ay_kn * x*x*x*x / Ay_kd
                + Ay_mn * x*x*x*y / Ay_md
                + Ay_nn * x*x*y*y / Ay_nd
                + Ay_pn * x*y*y*y / Ay_pd
                + Ay_qn * y*y*y*y / Ay_qd;

        v->x = v->x / 10; //this removes the 10x multiplier from the calibration values
        v->y = v->y / 10; //this removes the 10x multiplier from the calibration values

        v->x -= CAMERA_A_X; //this adjusts the x value of the measurement by the calibrated camera position
        v->y -= CAMERA_A_Y; //this adjusts the y value of the measurement by the calibrated camera position
        v->z = -CAMERA_A_Z; //this adjusts the z value of the measurement by the calibrated camera position

    }else{                //camera B
        v->x =    Bx_an * 1       / Bx_ad
                + Bx_bn * x       / Bx_bd
                + Bx_cn * x*x     / Bx_cd
                + Bx_dn * y       / Bx_dd
                + Bx_en * y*y     / Bx_ed
                + Bx_fn * x*y     / Bx_fd
                + Bx_gn * x*x*x   / Bx_gd
                + Bx_hn * x*x*y   / Bx_hd
                + Bx_in * x*y*y   / Bx_id
                + Bx_jn * y*y*y   / Bx_jd
                + Bx_kn * x*x*x*x / Bx_kd
                + Bx_mn * x*x*x*y / Bx_md
                + Bx_nn * x*x*y*y / Bx_nd
                + Bx_pn * x*y*y*y / Bx_pd
                + Bx_qn * y*y*y*y / Bx_qd;

        v->y =    By_an * 1       / By_ad
                + By_bn * x       / By_bd
                + By_cn * x*x     / By_cd
                + By_dn * y       / By_dd
                + By_en * y*y     / By_ed
                + By_fn * x*y     / By_fd
                + By_gn * x*x*x   / By_gd
                + By_hn * x*x*y   / By_hd
                + By_in * x*y*y   / By_id
                + By_jn * y*y*y   / By_jd
                + By_kn * x*x*x*x / By_kd
                + By_mn * x*x*x*y / By_md
                + By_nn * x*x*y*y / By_nd
                + By_pn * x*y*y*y / By_pd
                + By_qn * y*y*y*y / By_qd;

        v->x = v->x / 10; //this removes the 10x multiplier from the calibration values
        v->y = v->y / 10; //this removes the 10x multiplier from the calibration values

        v->x -= CAMERA_B_X;
        v->y -= CAMERA_B_Y;
        v->z = -CAMERA_B_Z;
    }




    vector_print(v);
}

void vector_cross(vector* a, vector* b, vector* vout){
    vout->x = a->y * b->z - a->z * b->y;
    vout->y = a->z * b->x - a->x * b->z;
    vout->z = a->x * b->y - a->y * b->x;
//  vector_print(vout);
}

long long vector_magnitude(vector* v){
    long long value = rootEstimation((long long)v->x * (long long)v->x + (long long)v->y * (long long)v->y + (long long)v->z * (long long)v->z);
    return (long long)value;
}

long long vector_togetherness(vector* a, vector* b, testResult* result){
    //get normal vector
    vector_cross(a,b,&result->n);

    //get togetherness, which tests if two vectors meet in front of the camera or behind the camera (meaning they point away from each other)
    result->togetherness = ((long long)c1 * (long long)result->n.y - (long long)c2 * ((long long)result->n.x - (long long)CAMERA_A_X) - (long long) CAMERA_A_Y);
//  printf("togetherness = %lld\n", result->togetherness);

    return result->togetherness;
}

long long vector_normalDistance(vector* a, vector* b, testResult* result){
    //get normal distance
    result->d_numerator = (long long)result->n.x*(long long)c1 + (long long)result->n.y*(long long)c2 + (long long)result->n.z*(long long)c3;
    result->d_denominator = (long long)result->n.x*(long long)result->n.x+(long long)result->n.y*(long long)result->n.y+(long long)result->n.z*(long long)result->n.z;
    result->n_magnitude = rootEstimation(result->d_denominator);

//  result->distance = result->d_numerator * result->n_magnitude;
//  result->distance = result->distance / result->d_denominator;
    result->distance = result->d_numerator / result->n_magnitude;

//  printf("ax=%d ay=%d az=%d bx=%d by=%d bz=%d c1=%d c2=%d c3=%d nx=%d ny=%d nz=%d\n",a->x,a->y,a->z,b->x,b->y,b->z,c1,c2,c3,result->n.x,result->n.y,result->n.z); //print all vars
//  printf("d_numerator = %lld\t d_denominator = %lld\t normal distance = %lld\t nmag = %lld\n", result->d_numerator, result->d_denominator, result->distance, result->n_magnitude);

    return result->distance;
}

void vector_getTargetPoint(vector* a, vector* b, testResult* result){
    long long tx;
    long long ty;
    long long tz;

    //get the parameter r to actually find the point in 3d space
    result->r_numerator = ((long long)a->x * (long long)c2 - (long long)c1 * (long long)a->y) - ((long long)a->x * (long long)result->n.y - (long long)a->y * (long long)result->n.x) * result->d_numerator / result->d_denominator;
    result->r_denominator = -result->n.z;

    if(result->r_numerator > 1000000000000 && result->r_denominator > 1000000000000){  //some simple division to prevent overflow
        result->r_numerator /= 100000000;
        result->r_denominator /= 100000000;
    }
//  printf("r_numerator = %lld\t r_denominator = %lld\t r = %lld\n", result->r_numerator, result->r_denominator, result->r_numerator / result->r_denominator);

    //get the target point based on parameter r
    tx = CAMERA_B_X + b->x * result->r_numerator / result->r_denominator;
    ty = CAMERA_B_Y + b->y * result->r_numerator / result->r_denominator;
    tz = CAMERA_B_Z + b->z * result->r_numerator / result->r_denominator;
    result->target.x = (int)tx;
    result->target.y = (int)ty;
    result->target.z = (int)tz;
    //printf("target point at x = %d  \ty = %d  \tz= %d\n",result->target.x,result->target.y,result->target.z);
}

void vector_print(vector* v){
    //printf("vector x = %d\t y = %d\t z = %d\n", v->x, v->y, v->z);
}

long long rootEstimation(long long originalNumber){  // this could be faster by quickly moving away from long long math
    int n;
    long long number = originalNumber;
    unsigned long long x;
    unsigned int y;
    n = 64;
    x = number>>32; if(x!=0) {n -= 32; number = x;}
    x = number>>16; if(x!=0) {n -= 16; number = x;}
    x = number>>8;  if(x!=0) {n -= 8; number = x;}
    x = number>>4;  if(x!=0) {n -= 4; number = x;}
    x = number>>2;  if(x!=0) {n -= 2; number = x;}
    x = number>>1;  if(x!=0) {n -= 2;} else {n -= (int)number;}
    x = (unsigned long long)rootEstimationTable[n];
//  printf("Original number = %lld\t Leading Zeros = %d\t root estimation table = %lld",originalNumber,n,x);
    if(n > 31){
        y = (int)x;
        y = (y + (int)originalNumber/y)/2;
        y = (y + (int)originalNumber/y)/2;
        y = (y + (int)originalNumber/y)/2;
        y = (y + (int)originalNumber/y)/2;
//      printf("\t root estimation = %d\n",y);
        return (long long)y;
    }else{
        x = (x + originalNumber/x)/2;
        x = (x + originalNumber/x)/2;
        x = (x + originalNumber/x)/2;
        x = (x + originalNumber/x)/2;
//      printf("\t root estimation = %lld",x);
        return x;
    }
}
