const std = @import("std");

pub fn vec(comptime Scalar: type, comptime n: comptime_int) type {
    return struct {
        pub const Vec = [n]Scalar;

        pub fn zeroes() Vec {
            return .{0} ** n;
        }

        pub fn negate(v: Vec) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = -v[i];
            return res;
        }

        pub fn add(v1: Vec, v2: Vec) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v1[i] + v2[i];
            return res;
        }

        pub fn subtract(v1: Vec, v2: Vec) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v1[i] - v2[i];
            return res;
        }

        pub fn multiply(v1: Vec, v2: Vec) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v1[i] * v2[i];
            return res;
        }

        pub fn divide(v1: Vec, v2: Vec) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v1[i] / v2[i];
            return res;
        }

        pub fn addS(v: Vec, s: Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v[i] + s;
            return res;
        }

        pub fn subtractS(v: Vec, s: Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v[i] - s;
            return res;
        }

        pub fn multiplyS(v: Vec, s: Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v[i] * s;
            return res;
        }

        pub fn multiplySH(v: Vec, s: Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n - 1) : (i += 1)
                res[i] = v[i] * s;
            return res;
        }

        pub fn divideS(v: Vec, s: Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v[i] / s;
            return res;
        }

        pub fn divideSH(v: Vec, s: Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n - 1) : (i += 1)
                res[i] = v[i] / s;
            return res;
        }

        pub fn min(v1: Vec, v2: Vec) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = std.math.min(v1[i], v2[i]);
            return res;
        }

        pub fn max(v1: Vec, v2: Vec) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = std.math.max(v1[i], v2[i]);
            return res;
        }

        pub fn sum(v: Vec) Scalar {
            var res: Scalar = 0;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res += v[i];
            return res;
        }

        pub fn dot(v1: Vec, v2: Vec) Scalar {
            return sum(multiply(v1, v2));
        }

        pub fn norm(v: Vec) Scalar {
            var res: Scalar = 0;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res += v[i] * v[i];
            return res;
        }

        pub fn abs(v: Vec) Scalar {
            return @sqrt(norm(v));
        }

        pub fn normalize(v: Vec) Vec {
            return divideS(v, abs(v));
        }

        pub fn fromLower(v: [n - 1]Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n - 1) : (i += 1)
                res[i] = v[i];
            res[n - 1] = 1;
            return res;
        }

        pub fn fromHigher(v: [n + 1]Scalar) Vec {
            var res: Vec = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i] = v[i] / v[n];
            return res;
        }
    };
}

// Mat[col][row]
pub fn mat(comptime Scalar: type, comptime n: comptime_int) type {
    return struct {
        pub const Mat = [n][n]Scalar;
        pub const Vec = [n]Scalar;

        pub fn zeroes() Mat {
            return .{.{0} ** n} ** n;
        }

        pub fn identity() Mat {
            var res = zeroes();
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i][i] = 1;
            return res;
        }

        pub fn multiply(m1: Mat, m2: Mat) Mat {
            var res = zeroes();
            comptime var i = 0;
            inline while (i < n) : (i += 1) {
                comptime var j = 0;
                inline while (j < n) : (j += 1) {
                    comptime var k = 0;
                    inline while (k < n) : (k += 1) {
                        res[i][j] += m1[k][j] * m2[i][k];
                    }
                }
            }
            return res;
        }

        pub fn multiplyV(m: Mat, v: Vec) Vec {
            var res: Vec = .{0} ** n;
            comptime var i = 0;
            inline while (i < n) : (i += 1) {
                comptime var j = 0;
                inline while (j < n) : (j += 1) {
                    res[i] += m[j][i] * v[j];
                }
            }
            return res;
        }

        pub fn multiplyVH(m: Mat, v: [n - 1]Scalar) [n - 1]Scalar {
            const vh = vec(Scalar, n - 1).toHomogenous(v);
            return vec(Scalar, n - 1).fromHomogenous(multiplyV(m, vh));
        }

        pub fn transpose(m: Mat) Mat {
            var res: Mat = undefined;
            comptime var i = 0;
            inline while (i < n) : (i += 1) {
                comptime var j = 0;
                inline while (j < n) : (j += 1) {
                    res[i][j] = m[j][i];
                }
            }
            return res;
        }

        pub fn translate(v: [n - 1]Scalar) Mat {
            var res = identity();
            comptime var i = 0;
            inline while (i < n - 1) : (i += 1)
                res[n - 1][i] = v[i];
            return res;
        }

        pub fn scale(v: Vec) Mat {
            var res = identity();
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i][i] = v[i];
            return res;
        }

        pub fn scaleS(s: Scalar) Mat {
            var res = identity();
            comptime var i = 0;
            inline while (i < n) : (i += 1)
                res[i][i] = s;
            return res;
        }

        pub fn scaleSH(s: Scalar) Mat {
            var res = identity();
            comptime var i = 0;
            inline while (i < n - 1) : (i += 1)
                res[i][i] = s;
            return res;
        }

        pub fn rotate(comptime axis1: comptime_int, comptime axis2: comptime_int, angle: Scalar) Mat {
            var res = identity();
            res[axis1][axis1] = @cos(angle);
            res[axis1][axis2] = @sin(angle);
            res[axis2][axis1] = -@sin(angle);
            res[axis2][axis2] = @cos(angle);
            return res;
        }

        pub fn fromLower(v: [n - 1][n - 1]Scalar) Mat {
            var res: Mat = identity();
            comptime var i = 0;
            inline while (i < n - 1) : (i += 1) {
                comptime var j = 0;
                inline while (j < n - 1) : (j += 1) {
                    res[i][j] = v[i][j];
                }
            }
            return res;
        }
    };
}
