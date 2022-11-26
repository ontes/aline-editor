const std = @import("std");

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
