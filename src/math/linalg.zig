const std = @import("std");

pub const vec2 = @import("linalg.zig").vec(2, f32);
pub const Vec2 = vec2.Vector;

pub const vec3 = @import("linalg.zig").vec(3, f32);
pub const Vec3 = vec3.Vector;

pub const mat2 = @import("linalg.zig").mat(2, f32);
pub const Mat2 = mat2.Matrix;

pub const mat3 = @import("linalg.zig").mat(3, f32);
pub const Mat3 = mat3.Matrix;

pub fn vec(comptime len: comptime_int, comptime Scalar: type) type {
    return struct {
        pub const Vector = @Vector(len, Scalar);

        pub const zero = splat(0);

        pub inline fn splat(sc: Scalar) Vector {
            return @splat(len, sc);
        }

        pub inline fn dot(v1: Vector, v2: Vector) Scalar {
            return @reduce(.Add, v1 * v2);
        }

        pub inline fn norm(v: Vector) Scalar {
            return @reduce(.Add, v * v);
        }

        pub inline fn abs(v: Vector) Scalar {
            return @sqrt(norm(v));
        }

        pub inline fn normalize(v: Vector) Vector {
            return v / splat(abs(v));
        }
    };
}

// matrix[col][row]
pub fn mat(comptime len: comptime_int, comptime Scalar: type) type {
    return struct {
        const vector = vec(len, Scalar);
        const Vector = vector.Vector;
        pub const Matrix = [len]Vector;

        pub const zero = [_]Vector{vector.zero} ** len;

        pub const id = id: {
            var res = zero;
            comptime var i = 0;
            inline while (i < len) : (i += 1)
                res[i][i] = 1;
            break :id res;
        };

        pub fn mult(m0: Matrix, m1: Matrix) Matrix {
            var res = zero;
            comptime var i = 0;
            inline while (i < len) : (i += 1) {
                comptime var j = 0;
                inline while (j < len) : (j += 1) {
                    res[i] += m0[j] * vector.splat(m1[i][j]);
                }
            }
            return res;
        }

        pub fn multVec(m: Matrix, v: Vector) Vector {
            var res = vector.zero;
            comptime var i = 0;
            inline while (i < len) : (i += 1)
                res += m[i] * vector.splat(v[i]);
            return res;
        }

        pub fn transpose(m: Matrix) Matrix {
            var res: Matrix = undefined;
            comptime var i = 0;
            inline while (i < len) : (i += 1) {
                comptime var j = 0;
                inline while (j < len) : (j += 1) {
                    res[i][j] = m[j][i];
                }
            }
            return res;
        }

        pub fn determinant(m: Matrix) Scalar {
            if (len == 1)
                return m[0][0];
            const lmat = mat(len - 1, Scalar);

            var res: Scalar = 0;
            comptime var i = 0;
            inline while (i < len) : (i += 1) {
                var lm: lmat.Matrix = undefined;
                comptime var x = 0;
                inline while (x + 1 < len) : (x += 1) {
                    comptime var y = 0;
                    inline while (y + 1 < len) : (y += 1) {
                        lm[x][y] = m[if (x < i) x else x + 1][y + 1];
                    }
                }
                res += lmat.determinant(lm) * m[i][0] * (if (i % 2 == 0) 1 else -1);
            }
            return res;
        }

        pub fn translate(v: @Vector(len - 1, Scalar)) Matrix {
            var res = id;
            comptime var i = 0;
            inline while (i < len - 1) : (i += 1)
                res[len - 1][i] = v[i];
            return res;
        }

        pub fn scale(v: Vector) Matrix {
            var res = id;
            comptime var i = 0;
            inline while (i < len) : (i += 1)
                res[i][i] = v[i];
            return res;
        }

        pub fn rotate(comptime axis1: comptime_int, comptime axis2: comptime_int, angle: Scalar) Matrix {
            var res = id;
            res[axis1][axis1] = @cos(angle);
            res[axis1][axis2] = @sin(angle);
            res[axis2][axis1] = -@sin(angle);
            res[axis2][axis2] = @cos(angle);
            return res;
        }
    };
}
