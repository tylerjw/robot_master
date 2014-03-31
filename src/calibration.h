/*
 * calibration.h
 *
 *  Created on: Jan 6, 2014
 *      Author: rdbeethe
 */

#ifndef CALIBRATION_H_
#define CALIBRATION_H_

#define CAMERA_A_X -108
#define CAMERA_A_Y 20
#define CAMERA_A_Z 270

#define CAMERA_B_X 97
#define CAMERA_B_Y 20
#define CAMERA_B_Z 270


//*******ALL NUMERATORS BELOW ARE MULIPLIED BY 10 TO INCREASE THE PRECISION OF THE ESTIMATION
//*******A "divide by 10" instruction is included after the polynomial approximation

//Camera A, constants to determine x component of vector from pixel data:
#define Ax_an ((float)-42139) //-4.2139E+02
#define Ax_ad ((float)1e1)
#define Ax_bn ((float)16382) //1.6382E+00
#define Ax_bd ((float)1e3)
#define Ax_cn ((float)-17029) //-1.7029E-03
#define Ax_cd ((float)1e6)
#define Ax_dn ((float)12745) //1.2745E+00
#define Ax_dd ((float)1e3)
#define Ax_en ((float)-34073) //-3.4073E-03
#define Ax_ed ((float)1e6)
#define Ax_fn ((float)-46006) //-4.6006E-03
#define Ax_fd ((float)1e6)
#define Ax_gn ((float)16855) //1.6855E-06
#define Ax_gd ((float)1e9)
#define Ax_hn ((float)26347) //2.6347E-06
#define Ax_hd ((float)1e9)
#define Ax_in ((float)89641) //8.9641E-06
#define Ax_id ((float)1e9)
#define Ax_jn ((float)44565) //4.4565E-06
#define Ax_jd ((float)1e9)
#define Ax_kn ((float)12924) //1.2924E-09
#define Ax_kd ((float)1e12)
#define Ax_mn ((float)-49388) //-4.9388E-09
#define Ax_md ((float)1e12)
#define Ax_nn ((float)14475) //1.4475E-09
#define Ax_nd ((float)1e12)
#define Ax_pn ((float)-77884) //-7.7884E-09
#define Ax_pd ((float)1e12)
#define Ax_qn ((float)-23422) //-2.3422E-09
#define Ax_qd ((float)1e12)

//Camera A, constants to determine y component of vector from pixel data:
#define Ay_an ((float)57395) //5.7395E+02
#define Ay_ad ((float)1e1)
#define Ay_bn ((float)-26110) //-2.6110E-01
#define Ay_bd ((float)1e4)
#define Ay_cn ((float)52239) //5.2239E-04
#define Ay_cd ((float)1e7)
#define Ay_dn ((float)-26963) //-2.6963E+00
#define Ay_dd ((float)1e3)
#define Ay_en ((float)76041) //7.6041E-03
#define Ay_ed ((float)1e6)
#define Ay_fn ((float)13934) //1.3934E-03
#define Ay_fd ((float)1e6)
#define Ay_gn ((float)86844) //8.6844E-07
#define Ay_gd ((float)1e10)
#define Ay_hn ((float)-46282) //-4.6282E-06
#define Ay_hd ((float)1e9)
#define Ay_in ((float)12052) //1.2052E-07
#define Ay_id ((float)1e10)
#define Ay_jn ((float)-13479) //-1.3479E-05
#define Ay_jd ((float)1e8)
#define Ay_kn ((float)-41211) //-4.1211E-10
#define Ay_kd ((float)1e13)
#define Ay_mn ((float)-10621) //-1.0621E-09
#define Ay_md ((float)1e12)
#define Ay_nn ((float)60566) //6.0566E-09
#define Ay_nd ((float)1e12)
#define Ay_pn ((float)-29709) //-2.9709E-09
#define Ay_pd ((float)1e12)
#define Ay_qn ((float)96550) //9.6550E-09
#define Ay_qd ((float)1e12)


//Camera B, constants to determine x component of vector from pixel data:
#define Bx_an ((float)-73445) //-7.3445E+02
#define Bx_ad ((float)1e1)
#define Bx_bn ((float)35456) //3.5456E+00
#define Bx_bd ((float)1e3)
#define Bx_cn ((float)-58859) //-5.8859E-03
#define Bx_cd ((float)1e6)
#define Bx_dn ((float)28090) //2.8090E+00
#define Bx_dd ((float)1e3)
#define Bx_en ((float)-53605) //-5.3605E-03
#define Bx_ed ((float)1e6)
#define Bx_fn ((float)-98219) //-9.8219E-03
#define Bx_fd ((float)1e6)
#define Bx_gn ((float)59217) //5.9217E-06
#define Bx_gd ((float)1e9)
#define Bx_hn ((float)97157) //9.7157E-06
#define Bx_hd ((float)1e9)
#define Bx_in ((float)14293) //1.4293E-05
#define Bx_id ((float)1e8)
#define Bx_jn ((float)42237) //4.2237E-06
#define Bx_jd ((float)1e9)
#define Bx_kn ((float)-16133) //-1.6133E-09
#define Bx_kd ((float)1e12)
#define Bx_mn ((float)-58089) //-5.8089E-09
#define Bx_md ((float)1e12)
#define Bx_nn ((float)-40282) //-4.0282E-09
#define Bx_nd ((float)1e12)
#define Bx_pn ((float)-87192) //-8.7192E-09
#define Bx_pd ((float)1e12)
#define Bx_qn ((float)-52593) //-5.2593E-10
#define Bx_qd ((float)1e13)

//Camera B, constants to determine y component of vector from pixel data:
#define By_an ((float)83491) //8.3491E+02
#define By_ad ((float)1e1)
#define By_bn ((float)-10522) //-1.0522E+00
#define By_bd ((float)1e3)
#define By_cn ((float)12764) //1.2764E-03
#define By_cd ((float)1e6)
#define By_dn ((float)-44774) //-4.4774E+00
#define By_dd ((float)1e3)
#define By_en ((float)11863) //1.1863E-02
#define By_ed ((float)1e5)
#define By_fn ((float)63685) //6.3685E-03
#define By_fd ((float)1e6)
#define By_gn ((float)40244) //4.0244E-08
#define By_gd ((float)1e11)
#define By_hn ((float)-75968) //-7.5968E-06
#define By_hd ((float)1e9)
#define By_in ((float)-85077) //-8.5077E-06
#define By_id ((float)1e9)
#define By_jn ((float)-18238) //-1.8238E-05
#define By_jd ((float)1e8)
#define By_kn ((float)-31646) //-3.1646E-10
#define By_kd ((float)1e13)
#define By_mn ((float)14307) //1.4307E-09
#define By_md ((float)1e12)
#define By_nn ((float)68650) //6.8650E-09
#define By_nd ((float)1e12)
#define By_pn ((float)29933) //2.9933E-09
#define By_pd ((float)1e12)
#define By_qn ((float)11560) //1.1560E-08
#define By_qd ((float)1e11)


#endif /* CALIBRATION_H_ */
