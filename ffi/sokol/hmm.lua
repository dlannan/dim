local ffi  = require( "ffi" )

local libs = ffi_hmm_dll or {
   OSX     = { x64 = "hmm_dll_macos.so", arm64 = "hmm_dll_macos_arm64.so" },
   Windows = { x64 = "hmm_dll.dll" },
   Linux   = { x64 = "./bin/linux/lib".."hmm_dll.so", arm = "./bin/linux/lib".."hmm_dll.so" },
   BSD     = { x64 = "hmm_dll.so" },
   POSIX   = { x64 = "hmm_dll.so" },
   Other   = { x64 = "hmm_dll.so" },
}

local lib  = ffi_hmm_dll or libs[ ffi.os ][ ffi.arch ]
local hmm_lib   = ffi.load( lib )

ffi.cdef[[

/********** hmm_lib ****************************************************************/

typedef union hmm_vec2
{
    struct
    {
        float x, y;
    };

    struct
    {
        float X, Y;
    };

    struct
    {
        float U, V;
    };

    struct
    {
        float Left, Right;
    };
    
    struct
    {
        float Width, Height;
    };

    float Elements[2];
} hmm_vec2;

typedef union hmm_vec3
{
    struct
    {
        float x, y, z;
    };

    struct
    {
        float X, Y, Z;
    };

    struct
    {
        float U, V, W;
    };

    struct
    {
        float R, G, B;
    };

    struct
    {
        hmm_vec2 XY;
        float Ignored0_;
    };

    struct
    {
        float Ignored1_;
        hmm_vec2 YZ;
    };

    struct
    {
        hmm_vec2 UV;
        float Ignored2_;
    };

    struct
    {
        float Ignored3_;
        hmm_vec2 VW;
    };

    float Elements[3];
} hmm_vec3;

typedef union hmm_vec4
{
    struct
    {
        union
        {
            hmm_vec3 XYZ;
            struct
            {
                float X, Y, Z;
            };
            struct
            {
                float x, y, z;
            };        
        };
        union
        {
            float W;
            float w;
        };
    };
    struct
    {
        union
        {
            hmm_vec3 RGB;
            struct
            {
                float R, G, B;
            };
            struct
            {
                float x, y, z;
            };        
        };

        union 
        {
            float A;
            float a;
        };
    };

    struct
    {
        hmm_vec2 XY;
        float Ignored0_;
        float Ignored1_;
    };

    struct
    {
        float Ignored2_;
        hmm_vec2 YZ;
        float Ignored3_;
    };

    struct
    {
        float Ignored4_;
        float Ignored5_;
        hmm_vec2 ZW;
    };

    float Elements[4];
} hmm_vec4;

typedef union hmm_mat2
{
    float Elements[2][2];

} hmm_mat2;

typedef union hmm_mat3
{
    float Elements[3][3];

} hmm_mat3;

typedef union hmm_mat4
{
    float Elements[4][4];

} hmm_mat4;

typedef union hmm_quaternion
{
    struct
    {
        union
        {
            hmm_vec3 XYZ;
            struct
            {
                float X, Y, Z;
            };
            struct
            {
                float x, y, z;
            };        
        };
        
        union
        {
            float W;
            float w;
        };
    };
    
    float Elements[4];
} hmm_quaternion;

typedef int32_t hmm_bool;

typedef hmm_vec2 hmm_v2;
typedef hmm_vec3 hmm_v3;
typedef hmm_vec4 hmm_v4;
typedef hmm_mat4 hmm_m4;    

float HMM_SinF(float Angle);
float HMM_TanF(float Angle);
float HMM_ATanF(float Theta);
float HMM_ATan2F(float Theta, float Theta2);
float HMM_CosF(float Angle);
float HMM_ACosF(float Theta);
float HMM_ExpF(float Float);
float HMM_LogF(float Float);
float HMM_SqrtF(float Float);
float HMM_InvSqrtF(float Float);

float HMM_ToRad(float Degrees);
float HMM_ToDeg(float Radians);
float HMM_ToTurn(float Angle);

float HMM_Power(float Base, int Exponent);
float HMM_PowerF(float Base, float Exponent);
float HMM_Lerp(float A, float Time, float B);
float HMM_Clamp(float Min, float Value, float Max);

hmm_vec3 HMM_Cross(hmm_vec3 VecOne, hmm_vec3 VecTwo);

hmm_vec2 HMM_V2(float X, float Y);
hmm_vec2 HMM_Vec2i(int X, int Y);
hmm_vec3 HMM_V3(float X, float Y, float Z);
hmm_vec3 HMM_Vec3i(int X, int Y, int Z);
hmm_vec4 HMM_V4(float X, float Y, float Z, float W);
hmm_vec4 HMM_Vec4i(int X, int Y, int Z, int W);
hmm_vec4 HMM_V4V(hmm_vec3 Vector, float W);

hmm_vec2 HMM_AddV2(hmm_vec2 Left, hmm_vec2 Right);
hmm_vec3 HMM_AddV3(hmm_vec3 Left, hmm_vec3 Right);
hmm_vec4 HMM_AddV4(hmm_vec4 Left, hmm_vec4 Right);

hmm_vec2 HMM_SubV2(hmm_vec2 Left, hmm_vec2 Right);
hmm_vec3 HMM_SubV3(hmm_vec3 Left, hmm_vec3 Right);
hmm_vec4 HMM_SubV4(hmm_vec4 Left, hmm_vec4 Right);

hmm_vec2 HMM_MulV2(hmm_vec2 Left, hmm_vec2 Right);
hmm_vec2 HMM_MulV2F(hmm_vec2 Left, float Right);
hmm_vec3 HMM_MulV3(hmm_vec3 Left, hmm_vec3 Right);
hmm_vec3 HMM_MulV3F(hmm_vec3 Left, float Right);
hmm_vec4 HMM_MulV4(hmm_vec4 Left, hmm_vec4 Right);
hmm_vec4 HMM_MulV4F(hmm_vec4 Left, float Right);

hmm_vec2 HMM_DivV2(hmm_vec2 Left, hmm_vec2 Right);
hmm_vec2 HMM_DivV2F(hmm_vec2 Left, float Right);
hmm_vec3 HMM_DivV3(hmm_vec3 Left, hmm_vec3 Right);
hmm_vec3 HMM_DivV3F(hmm_vec3 Left, float Right);
hmm_vec4 HMM_DivV4(hmm_vec4 Left, hmm_vec4 Right);
hmm_vec4 HMM_DivV4F(hmm_vec4 Left, float Right);

hmm_bool HMM_EqV2(hmm_vec2 Left, hmm_vec2 Right);
hmm_bool HMM_EqV3(hmm_vec3 Left, hmm_vec3 Right);
hmm_bool HMM_EqV4(hmm_vec4 Left, hmm_vec4 Right);

float HMM_DotV2(hmm_vec2 Left, hmm_vec2 Right);
float HMM_DotV3(hmm_vec3 Left, hmm_vec3 Right);
float HMM_DotV4(hmm_vec4 Left, hmm_vec4 Right);

hmm_vec3 HMM_Cross(hmm_vec3 Left, hmm_vec3 Right);

float HMM_LenSqrV2(hmm_vec2 A);
float HMM_LenSqrV3(hmm_vec3 A);
float HMM_LenSqrV4(hmm_vec4 A);

float HMM_LenV2(hmm_vec2 A);    
float HMM_LenV3(hmm_vec3 A);    
float HMM_LenV4(hmm_vec4 A);    

hmm_vec2 HMM_NormV2(hmm_vec2 A);
hmm_vec3 HMM_NormV3(hmm_vec3 A);
hmm_vec4 HMM_NormV4(hmm_vec4 A);

hmm_vec2 HMM_LerpV2(hmm_vec2 A, float Time, hmm_vec2 B);
hmm_vec3 HMM_LerpV3(hmm_vec3 A, float Time, hmm_vec3 B);
hmm_vec4 HMM_LerpV4(hmm_vec4 A, float Time, hmm_vec4 B);

hmm_vec4 HMM_LinearCombineV4M4(hmm_vec4 Left, hmm_vec4 Right);

hmm_mat2 HMM_M2(void);
hmm_mat2 HMM_M2D(float Diagonal);
hmm_mat2 HMM_TransposeM2(hmm_mat2 Matrix);
hmm_mat2 HMM_AddM2(hmm_mat2 Left, hmm_mat2 Right);
hmm_mat2 HMM_SubM2(hmm_mat2 Left, hmm_mat2 Right);
hmm_vec2 HMM_MulM2V2(hmm_mat2 Matrix, hmm_vec2 Vector);
hmm_mat2 HMM_MulM2(hmm_mat2 Left, hmm_mat2 Right);
hmm_mat2 HMM_MulM2F(hmm_mat2 Matrix, float Scalar);
hmm_mat2 HMM_DivM2F(hmm_mat2 Matrix, float Scalar);
float HMM_DeterminantM2(hmm_mat2 Matrix);
hmm_mat2 HMM_InvGeneralM2(hmm_mat2 Matrix);

hmm_mat3 HMM_M3(void);
hmm_mat3 HMM_M3D(float Diagonal);
hmm_mat3 HMM_TransposeM3(hmm_mat3 Matrix);
hmm_mat3 HMM_AddM3(hmm_mat3 Left, hmm_mat3 Right);
hmm_mat3 HMM_SubM3(hmm_mat3 Left, hmm_mat3 Right);
hmm_vec2 HMM_MulM3V3(hmm_mat3 Matrix, hmm_vec3 Vector);
hmm_mat3 HMM_MulM3(hmm_mat3 Left, hmm_mat3 Right);
hmm_mat3 HMM_MulM3F(hmm_mat3 Matrix, float Scalar);
hmm_mat3 HMM_DivM3F(hmm_mat3 Matrix, float Scalar);
float HMM_DeterminantM3(hmm_mat3 Matrix);
hmm_mat3 HMM_InvGeneralM3(hmm_mat3 Matrix);

hmm_mat4 HMM_M4(void);
hmm_mat4 HMM_M4D(float Diagonal);
hmm_mat4 HMM_TransposeM4(hmm_mat4 Matrix);
hmm_mat4 HMM_AddM4(hmm_mat4 Left, hmm_mat4 Right);
hmm_mat4 HMM_SubM4(hmm_mat4 Left, hmm_mat4 Right);
hmm_mat4 HMM_MulM4(hmm_mat4 Left, hmm_mat4 Right);
hmm_mat4 HMM_MulM4F(hmm_mat4 Matrix, float Scalar);
hmm_vec4 HMM_MulM4V4(hmm_mat4 Matrix, hmm_vec4 Vector);
hmm_mat4 HMM_DivM4F(hmm_mat4 Matrix, float Scalar);
float HMM_DeterminantM4(hmm_mat4 Matrix);
hmm_mat4 HMM_InvGeneralM4(hmm_mat4 Matrix);

hmm_mat4 HMM_Orthographic_RH_NO(float Left, float Right, float Bottom, float Top, float Near, float Far);
hmm_mat4 HMM_Orthographic_RH_ZO(float Left, float Right, float Bottom, float Top, float Near, float Far);
hmm_mat4 HMM_Orthographic_LH_NO(float Left, float Right, float Bottom, float Top, float Near, float Far);
hmm_mat4 HMM_Orthographic_RH_ZO(float Left, float Right, float Bottom, float Top, float Near, float Far);
hmm_mat4 HMM_InvOrthographic(hmm_mat4 OrthoMatrix);

hmm_mat4 HMM_Perspective_RH_NO(float FOV, float AspectRatio, float Near, float Far);
hmm_mat4 HMM_Perspective_RH_ZO(float FOV, float AspectRatio, float Near, float Far);
hmm_mat4 HMM_Perspective_LH_NO(float FOV, float AspectRatio, float Near, float Far);
hmm_mat4 HMM_Perspective_LH_ZO(float FOV, float AspectRatio, float Near, float Far);

hmm_mat4 HMM_InvPerspective_RH(hmm_mat4 PerspectiveMatrix);
hmm_mat4 HMM_InvPerspective_LH(hmm_mat4 PerspectiveMatrix);

hmm_mat4 HMM_Translate(hmm_vec3 Translation);
hmm_mat4 HMM_InvTranslate(hmm_mat4 TranslationMatrix);

hmm_mat4 HMM_Rotate_RH(float Angle, hmm_vec3 Axis);
hmm_mat4 HMM_Rotate_LH(float Angle, hmm_vec3 Axis);
hmm_mat4 HMM_InvRotate(hmm_mat4 RotationMatrix);

hmm_mat4 HMM_Scale(hmm_vec3 Scale);
hmm_mat4 HMM_InvScale(hmm_mat4 ScaleMatrix);

hmm_mat4 _HMM_LookAt(hmm_vec3 F,  hmm_vec3 S, hmm_vec3 U,  hmm_vec3 Eye);
hmm_mat4 HMM_LookAt_RH(hmm_vec3 Eye, hmm_vec3 Center, hmm_vec3 Up);
hmm_mat4 HMM_LookAt_LH(hmm_vec3 Eye, hmm_vec3 Center, hmm_vec3 Up);
hmm_mat4 HMM_InvLookAt(hmm_mat4 Matrix);

hmm_quaternion HMM_Q(float X, float Y, float Z, float W);
hmm_quaternion HMM_QV4(hmm_vec4 Vector);
hmm_quaternion HMM_AddQ(hmm_quaternion Left, hmm_quaternion Right);
hmm_quaternion HMM_SubQ(hmm_quaternion Left, hmm_quaternion Right);
hmm_quaternion HMM_MulQ(hmm_quaternion Left, hmm_quaternion Right);
hmm_quaternion HMM_MulQF(hmm_quaternion Left, float Multiplicative);
hmm_quaternion HMM_DivQF(hmm_quaternion Left, float Dividend);
float HMM_DotQ(hmm_quaternion Left, hmm_quaternion Right);
hmm_quaternion HMM_InvQ(hmm_quaternion Left);
hmm_quaternion HMM_NormQ(hmm_quaternion Left);
hmm_quaternion _HMM_MixQ(hmm_quaternion Left, float MixLeft, hmm_quaternion Right, float MixRight);
hmm_quaternion HMM_NLerp(hmm_quaternion Left, float Time, hmm_quaternion Right);
hmm_quaternion HMM_Slerp(hmm_quaternion Left, float Time, hmm_quaternion Right);
hmm_mat4 HMM_QToM4(hmm_quaternion Left);
hmm_quaternion HMM_M4ToQ_RH(hmm_mat4 M);
hmm_quaternion HMM_M4ToQ_LH(hmm_mat4 M);
hmm_quaternion HMM_QFromAxisAngle_RH(hmm_vec3 Axis, float AngleOfRotation);
hmm_quaternion HMM_QFromAxisAngle_LH(hmm_vec3 Axis, float AngleOfRotation);
hmm_quaternion HMM_QFromNormPair(hmm_vec3 Left, hmm_vec3 Right);
hmm_quaternion HMM_QFromVecPair(hmm_vec3 Left, hmm_vec3 Right);

hmm_vec2 HMM_RotateV2(hmm_vec2 V, float Angle);
hmm_vec3 HMM_RotateV3Q(hmm_vec3 V, hmm_quaternion Q);
hmm_vec3 HMM_RotateV3AxisAngle_LH(hmm_vec3 V, hmm_vec3 Axis, float Angle);
hmm_vec3 HMM_RotateV3AxisAngle_RH(hmm_vec3 V, hmm_vec3 Axis, float Angle);

]]

return hmm_lib