#pragma once
#include <stdint.h>
#include <math.h>

struct Vector3 { float x, y, z; };
struct Quaternion { float x, y, z, w; };
struct Matrix4x4 { float m[16]; };

static inline Vector3 v3(float x, float y, float z) { return {x, y, z}; }
static inline Vector3 v3_sub(Vector3 a, Vector3 b) { return {a.x-b.x, a.y-b.y, a.z-b.z}; }
static inline Vector3 v3_norm(Vector3 v) {
    float l = sqrtf(v.x*v.x + v.y*v.y + v.z*v.z);
    if (l < 0.0001f) return {0,0,0};
    return {v.x/l, v.y/l, v.z/l};
}
static inline float v3_dist(Vector3 a, Vector3 b) {
    Vector3 d = v3_sub(a,b);
    return sqrtf(d.x*d.x + d.y*d.y + d.z*d.z);
}
// row-major (m[linha*4 + coluna]), convenção Unity
static inline void mul_mat_vec(const Matrix4x4& m, const Vector3& v, float out[4]) {
    out[0] = m.m[0]*v.x + m.m[1]*v.y + m.m[2]*v.z + m.m[3];
    out[1] = m.m[4]*v.x + m.m[5]*v.y + m.m[6]*v.z + m.m[7];
    out[2] = m.m[8]*v.x + m.m[9]*v.y + m.m[10]*v.z + m.m[11];
    out[3] = m.m[12]*v.x + m.m[13]*v.y + m.m[14]*v.z + m.m[15];
}
static inline Quaternion look_rotation(Vector3 f) {
    f = v3_norm(f);
    Vector3 up = {0,1,0};
    Vector3 x = { up.y*f.z - up.z*f.y, up.z*f.x - up.x*f.z, up.x*f.y - up.y*f.x };
    x = v3_norm(x);
    Vector3 y = { f.y*x.z - f.z*x.y, f.z*x.x - f.x*x.z, f.x*x.y - f.y*x.x };
    float m00 = x.x, m01 = y.x, m02 = f.x;
    float m10 = x.y, m11 = y.y, m12 = f.y;
    float m20 = x.z, m21 = y.z, m22 = f.z;
    float tr = m00 + m11 + m22;
    Quaternion q;
    if (tr > 0) {
        float s = sqrtf(tr + 1.0f) * 2.0f;
        q.w = 0.25f * s;
        q.x = (m21 - m12) / s; q.y = (m02 - m20) / s; q.z = (m10 - m01) / s;
    } else if (m00 > m11 && m00 > m22) {
        float s = sqrtf(1.0f + m00 - m11 - m22) * 2.0f;
        q.w = (m21 - m12) / s; q.x = 0.25f * s;
        q.y = (m01 + m10) / s; q.z = (m02 + m20) / s;
    } else if (m11 > m22) {
        float s = sqrtf(1.0f + m11 - m00 - m22) * 2.0f;
        q.w = (m02 - m20) / s; q.x = (m01 + m10) / s;
        q.y = 0.25f * s; q.z = (m12 + m21) / s;
    } else {
        float s = sqrtf(1.0f + m22 - m00 - m11) * 2.0f;
        q.w = (m10 - m01) / s; q.x = (m02 + m20) / s;
        q.y = (m12 + m21) / s; q.z = 0.25f * s;
    }
    return q;
}
static inline Quaternion slerp(Quaternion a, Quaternion b, float t) {
    float dot = a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
    if (dot < 0) { b.x=-b.x; b.y=-b.y; b.z=-b.z; b.w=-b.w; dot=-dot; }
    if (dot > 0.9995f) return b;
    float th = acosf(dot), s = sinf(th);
    float wa = sinf((1-t)*th)/s, wb = sinf(t*th)/s;
    return { a.x*wa+b.x*wb, a.y*wa+b.y*wb, a.z*wa+b.z*wb, a.w*wa+b.w*wb };
}