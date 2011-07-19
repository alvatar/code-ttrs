/**A rational number implementation
 * By:  David Simcha
 *
 * License:
 * Boost Software License - Version 1.0 - August 17th, 2003
 *
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 *
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
 * SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
 * FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
module rational;


import std.algorithm, std.stdio, std.bigint, std.conv, std.math, std.contracts,
       std.conv;

/**Implements rational numbers on top of whatever integer type is specified
 * by the user.  If you use a fixed-size int, the onus is on you to make
 * sure nothing overflows.  Neither the denominator nor the numerator may
 * be bigger than the maximum value of the underlying integer.
 *
 * If you use an arbitrary precision type, it must have the relevant operators
 * overloaded and have value semantics.
 *
 * Examples:
 * ---
 * auto r1 = rational( BigInt("314159265"), BigInt("27182818"));
 * auto r2 = rational( BigInt("8675309"), BigInt("362436"));
 * r1 += r2;
 * assert(r1 == rational( BigInt("174840986505151"),
 *     BigInt("4926015912324")));
 *
 * // Print result.  Prints:
 * // "174840986505151 / 4926015912324"
 * writeln(f1);
 *
 * // Print result in decimal form.  Prints:
 * // "35.4934"
 * writeln(cast(real) result);
 * ---
 */
Rational!(Int) rational(Int)(Int i1, Int i2) {
    return Rational!(Int)(i1, i2);
}

///
struct Rational(Int) {
public:
    this(Int numerator, Int denominator) {
        this.numerator = numerator;
        this.denominator = denominator;
        simplify();
    }

    /**Multiply this by another Rational of the same type.*/
    typeof(this) opMul(typeof(this) rhs) {
        Rational ret = this;
        return ret *= rhs;
    }

    ///
    typeof(this) opMulAssign(typeof(this) rhs) {
        // Cancel common factors first, then multiply.  This prevents
        // overflows and is much more efficient when using BigInts.
        Int divisor = gcf(this.numerator, rhs.denominator);
        this.numerator /= divisor;
        rhs.denominator /= divisor;

        divisor = gcf(this.denominator, rhs.numerator);
        this.denominator /= divisor;
        rhs.numerator /= divisor;

        this.numerator *= rhs.numerator;
        this.denominator *= rhs.denominator;

        // Don't need to simplify.  Already cancelled common factors before
        // multiplying.
        fixSigns();
        return this;
    }

    /**Multiply this by an Int.*/
    typeof(this) opMul(Int rhs) {
        auto ret = this;
        return ret.opMulAssign(rhs);
    }

    ///
    typeof(this) opMulAssign(Int rhs) {
        Int divisor = gcf(this.denominator, rhs);
        this.denominator /= divisor;
        rhs /= divisor;
        this.numerator *= rhs;

        // Don't need to simplify.  Already cancelled common factors before
        // multiplying.
        fixSigns();
        return this;
    }

    /**Divide this by another Rational of the same type.*/
    typeof(this) opDiv(typeof(this) rhs) {
        // Division = multiply by inverse.
        swap(rhs.numerator, rhs.denominator);
        return this.opMul(rhs);
    }

    ///
    typeof(this) opDivAssign(typeof(this) rhs) {
        // Division = multiply by inverse.
        swap(rhs.numerator, rhs.denominator);
        return this.opMulAssign(rhs);
    }

    /**Divide this by an Int.*/
    typeof(this) opDiv(Int rhs) {
        typeof(this) ret = this;
        return ret.opDivAssign(rhs);
    }

    ///
    typeof(this) opDivAssign(Int rhs) {
        Int divisor = gcf(this.numerator, rhs);
        this.numerator /= divisor;
        rhs /= divisor;
        this.denominator *= rhs;

        // Don't need to simplify.  Already cancelled common factors before
        // multiplying.
        fixSigns();
        return this;
    }

    /**Divide an Int by this.*/
    typeof(this) opDiv_r(Int rhs) {
        typeof(this) ret;
        ret.numerator = this.denominator;
        ret.denominator = this.numerator;
        return ret *= rhs;
    }

    /**Add another Rational of the same type to this.*/
    typeof(this) opAdd(typeof(this) rhs) {
        typeof(this) ret = this;
        return ret.opAddAssign(rhs);
    }

    ///
    typeof(this) opAddAssign(typeof(this) rhs) {
        if(this.denominator == rhs.denominator) {
            this.numerator += rhs.numerator;
            simplify();
            return this;
        }

        Int commonDenom = lcm(this.denominator, rhs.denominator);
        this.numerator *= commonDenom / this.denominator;
        this.numerator += (commonDenom / rhs.denominator) * rhs.numerator;
        this.denominator = commonDenom;

        simplify();
        return this;
    }

    /**Add an Int to this.*/
    typeof(this) opAdd(Int rhs) {
        typeof(this) ret = this;
        return ret.opAddAssign(rhs);
    }

    ///
    typeof(this) opAddAssign(Int rhs) {
        this.numerator += rhs * this.denominator;

        simplify();
        return this;
    }

    /**Subtract another rational of the same type from this.*/
    typeof(this) opSub(typeof(this) rhs) {
        typeof(this) ret = this;
        return ret.opSubAssign(rhs);
    }

    ///
    typeof(this) opSubAssign(typeof(this) rhs) {
        if(this.denominator == rhs.denominator) {
            this.numerator -= rhs.numerator;
            simplify();
            return this;
        }

        Int commonDenom = lcm(this.denominator, rhs.denominator);
        this.numerator *= commonDenom / this.denominator;
        this.numerator -= (commonDenom / rhs.denominator) * rhs.numerator;
        this.denominator = commonDenom;

        simplify();
        return this;
    }

    /**Subtract an Int from this.*/
    typeof(this) opSub(Int rhs) {
        typeof(this) ret = this;
        return ret.opSubAssign(rhs);
    }

    ///
    typeof(this) opSubAssign(Int rhs) {
        this.numerator -= rhs * this.denominator;

        simplify();
        return this;
    }

    /**Subtract this from an Int.*/
    typeof(this) opSub_r(Int rhs) {
        typeof(this) ret;
        ret.denominator = this.denominator;
        ret.numerator = (rhs * this.denominator) - this.numerator;

        simplify();
        return ret;
    }

    /**Fast inversion, equivalent to 1 / rational.*/
    typeof(this) invert() {
        swap(numerator, denominator);
        return this;
    }

    ///
    bool opEquals(typeof(this) rhs) {
        // Assumption:  All rationals are in simplified form already.
        // This invariant is preserved by the c'tor and all operators.
        return this.numerator == rhs.numerator &&
            this.denominator == rhs.denominator;
    }

    ///
    bool opEquals(Int rhs) {
        return this.numerator == rhs && this.denominator == 1;
    }

    ///
    int opCmp(typeof(this) rhs) {
        if( opEquals(rhs)) {
            return 0;
        }

        // Check a few obvious cases first, see if we can avoid having to use a
        // common denominator.  These are basically speed hacks.

        // Assumption:  When simplify() is called, rational will be written in
        // canonical form, with any negative signs being only in the numerator.
        if(this.numerator < 0 && rhs.numerator > 0) {
            return -1;
        } else if(this.numerator > 0 && rhs.numerator < 0) {
            return 1;
        } else if(this.numerator >= rhs.numerator &&
            this.denominator <= rhs.denominator) {
            // We've already ruled out equality, so this must be > rhs.
            return 1;
        } else if(rhs.numerator >= this.numerator &&
            rhs.denominator <= this.denominator) {
            return -1;
        }

        // Can't do it without common denominator.  Argh.
        Int commonDenom = lcm(this.denominator, rhs.denominator);
        Int lhsNum = this.numerator * (commonDenom / this.denominator);
        Int rhsNum = rhs.numerator * (commonDenom / rhs.denominator);

        if(lhsNum > rhsNum) {
            return 1;
        } else if(lhsNum < rhsNum) {
            return -1;
        }

        // We've checked for equality already.  If we get to this point,
        // there's clearly something wrong.
        assert(0);
    }

    ///
    int opCmp(Int rhs) {
        if( opEquals(rhs)) {
            return 0;
        }

        // Again, check the obvious cases first.
        if(rhs >= this.numerator) {
            return -1;
        }

        rhs *= this.denominator;
        if(rhs > this.numerator) {
            return -1;
        } else if(rhs < this.numerator) {
            return 1;
        }

        // Already checked for equality.  If we get here, something's wrong.
        assert(0);
    }

    /**Convert to floating point representation.*/
    real opCast() {
        static if(isIntegral!(Int)) {
            return cast(real) numerator / cast(real) denominator;
        } else {
            // Start w/ integer part, keep dividing until we run out of
            // numbers or epsilon gets too small to affect ans.
            Rational temp = this;
            real expon = 1.0L;
            real ans = 0;
            byte sign = 1;
            if(temp.numerator < 0) {
                temp.numerator *= -1;
                sign = -1;
            }

            while(temp.numerator > 0) {
                while(temp.numerator < temp.denominator) {
                    temp.numerator <<= 1;
                    expon *= 0.5L;
                }

                Int intPart = temp.numerator / temp.denominator;
                long lIntPart = findEqualLong(intPart);

                // Test for changes.
                real oldAns = ans;
                ans += cast(real) lIntPart * expon;
                if(ans == oldAns) {  // Smaller than epsilon.
                    return ans * sign;
                }

                // Subtract out int part.
                temp.numerator -= intPart * temp.denominator;
            }

            return ans * sign;
        }
    }

    /**Returns the numerator.*/
    Int num() {
        return numerator;
    }

    /**Returns the denominator.*/
    Int denom() {
        return denominator;
    }

    ///
    string toString() {
        return to!string(numerator) ~ " / " ~ to!string(denominator);
    }

private :
    Int numerator;
    Int denominator;

    void simplify() {
        Int divisor = gcf(numerator, denominator);
        numerator /= divisor;
        denominator /= divisor;

        fixSigns();
    }

    void fixSigns() {
        static if( !is(Int == ulong) && !is(Int == uint) &&
            !is(Int == ushort) && !is(Int == ubyte)) {
            // Write in canonical form w.r.t. signs.
            if(denominator < 0) {
                denominator *= -1;
                numerator *= -1;
            }
        }
    }
}

unittest {
    // All reference values from the Maxima computer algebra system.

    // Test c'tor and simplification first.
    auto num = BigInt("295147905179352825852");
    auto den = BigInt("147573952589676412920");
    auto simpNum = BigInt("24595658764946068821");
    auto simpDen = BigInt("12297829382473034410");
    auto f1 = rational(num, den);
    auto f2 = rational(simpNum, simpDen);
    assert(f1 == f2);

    // Test multiplication.
    assert( rational(8, 42) * rational(7, 68) == rational(1, 51));
    assert(rational(20_000U, 3_486_784_401U) * rational(3_486_784_401U, 1_000U)
        == rational(20U, 1U));
    auto f3 = rational(7, 57);
    f3 *= rational(2, 78);
    assert(f3 == rational(7, 2223));
    f3 = 5 * f3;
    assert(f3 == rational(35, 2223));

    // Test division.  Since it's implemented in terms of multiplication,
    // quick and dirty tests should be good enough.
    assert( rational(7, 38) / rational(8, 79) == rational(553, 304));
    auto f4 = rational(7, 38);
    f4 /= rational(8, 79);
    assert(f4 == rational(553, 304));
    f4 = f4 / 2;
    assert(f4 == rational(553, 608));
    f4 = 2 / f4;
    assert(f4 == rational(1216, 553));

    // Test addition.
    assert( rational(1, 3) + rational(2, 3) == rational(1, 1));
    assert( rational(1, 3) + rational(1, 2) == rational(5, 6));
    auto f5 = rational( BigInt("314159265"), BigInt("27182818"));
    auto f6 = rational( BigInt("8675309"), BigInt("362436"));
    f5 += f6;
    assert(f5 == rational( BigInt("174840986505151"), BigInt("4926015912324")));
    assert( rational(1, 3) + 2 == rational(7, 3));
    assert( 5 + rational(1, 5) == rational(26, 5));

    // Test subtraction.
    assert( rational(2, 3) - rational(1, 3) == rational(1, 3));
    assert( rational(1, 2) - rational(1, 3) == rational(1, 6));
    f5 = rational( BigInt("314159265"), BigInt("27182818"));
    f5 -= f6;
    assert(f5 == rational( BigInt("-60978359135611"), BigInt("4926015912324")));
    assert( rational(4, 3) - 1 == rational(1, 3));
    assert(1 - rational(1, 4) == rational(3, 4));

    // Test decimal conversion.
    assert(approxEqual(cast(real) f5, -12.37883925284411L));

    // Test comparison.
    assert(rational(1, 6) < rational(1, 2));
    assert(rational(1, 2) > rational(1, 6));
    assert(rational(-1, 7) < rational(7, 2));
    assert(rational(7, 2) > rational(-1, 7));
    assert(rational(7, 9) > rational(8, 11));
    assert(rational(8, 11) < rational(7, 9));

    assert(rational(9, 10) < 1);
    assert(1 > rational(9, 10));
    assert(10 > rational(9, 10));
    assert(2 > rational(5, 4));
    assert(1 < rational(5, 4));

    writeln("Passed Rational unittest.");
}

/**Convert a floating point number to a Rational based on integer type Int.
 * Allows an error tolerance of epsilon.  (Default epsilon = 1e-8.)
 *
 * epsilon must be greater than 1.0L / long.max.
 *
 * Throws:  Exception on infinities, NaNs, numbers with absolute value
 * larger than long.max and epsilons smaller than 1.0L / long.max.
 *
 * Examples:
 * ---
 * // Prints "22 / 7".
 * writeln( toRational!int( PI, 1e-1));
 * ---
 */
Rational!(Int) toRational(Int)(real floatNum, real epsilon = 1e-8) {
    enforce(floatNum != real.infinity && floatNum != -real.infinity
        && !isNaN(floatNum), "Can't convert NaNs and infinities to rational.");
    enforce(floatNum < long.max && floatNum > -long.max,
        "Rational conversions of very large numbers not yet implemented.");
    enforce(1.0L / epsilon < long.max,
        "Can't handle very small epsilons < long.max in toRational.");

    // Handle this as a special case to make the rest of the code less
    // complicated:
    if( abs(floatNum) < epsilon) {
        Rational!Int ret;
        ret.numerator = 0;
        ret.denominator = 1;
        return ret;
    }

    return toRationalImpl!(Int)(floatNum, epsilon);
}

Rational!Int toRationalImpl(Int)(real floatNum, real epsilon) {
    real actualEpsilon;
    Rational!Int ret;

    if( abs(floatNum) < 1) {
        real invFloatNum = 1.0L / floatNum;
        long intPart = roundTo!long(invFloatNum);
        actualEpsilon = floatNum - 1.0L / intPart;

        static if(isIntegral!(Int)) {
            ret.denominator = cast(Int) intPart;
            ret.numerator = cast(Int) 1;
        } else {
            ret.denominator = intPart;
            ret.numerator = 1;
        }
    } else {
        long intPart = roundTo!long(floatNum);
        actualEpsilon = floatNum - intPart;

        static if(isIntegral!(Int)) {
            ret.denominator = cast(Int) 1;
            ret.numerator = cast(Int) intPart;
        } else {
            ret.denominator = 1;
            ret.numerator = intPart;
        }
    }

    if(abs(actualEpsilon) <= epsilon) {
        return ret;
    }

    // Else get results from downstream recursions, add them to this result.
    return ret + toRationalImpl!(Int)(actualEpsilon, epsilon);
}

unittest {
    // Start with simple cases.
    assert( toRational!int(0.5) == rational(1, 2));
    assert( toRational!BigInt(0.333333333333333L) ==
        rational( BigInt(1), BigInt(3)));
    assert( toRational!int(2.470588235294118) ==
        rational( cast(int) 42, cast(int) 17));
    assert( toRational!long(2.007874015748032) == rational(255L, 127L));
    assert( toRational!int( 3.0L / 7.0L) == rational(3, 7));
    assert( toRational!int( 7.0L / 3.0L) == rational(7, 3));

    // Now for some fun.
    real myEpsilon = 1e-8;
    auto piRational = toRational!long(PI, myEpsilon);
    assert( abs( cast(real) piRational - PI) < myEpsilon);

    auto eRational = toRational!long(E, myEpsilon);
    assert( abs( cast(real) eRational - E) < myEpsilon);
    writeln("Passed toRational unittest.");
}


/**Find the greatest common factor of num1 and num2 using Euclid's Algorithm.*/
Int gcf(Int)(Int num1, Int num2) {
    num1 = iAbs(num1);
    num2 = iAbs(num2);
    if(num2 > num1) {
        swap(num1, num2);
    } else if(num2 == num1) {
        return num1;
    }

    Int remainder = num1 % num2;
    if(remainder == 0) {
        return num2;
    } else {
        return gcf(num2, remainder);
    }
    assert(0);
}

unittest {
    // Values from the Maxima computer algebra system.
    assert(gcf( BigInt(314_156_535UL), BigInt(27_182_818_284UL)) == BigInt(3));
    assert(gcf(8675309, 362436) == 1);
    assert(gcf( BigInt("8589934596"), BigInt("295147905179352825852")) ==
        BigInt(12));

    writeln("Passed gcf unittest.");
}

/**Find the least common multiple of num1, num2.*/
Int lcm(Int)(Int num1, Int num2) {
    num1 = iAbs(num1);
    num2 = iAbs(num2);
    if(num1 == num2) {
        return num1;
    }
    return (num1 / gcf(num1, num2)) * num2;
}

/**Absolute value function that should gracefully handle any reasonable
 * BigInt implementation.*/
Int iAbs(Int)(Int num1) {
    return (num1 < 0) ? -1 * num1 : num1;
}

/* This function finds a long that is equal to any BigInt type by binary
 * search if one exists.  It is a massive kludge b/c there's no standard way
 * to cast a BigInt to a native type yet.  If one can't be found (the number
 * is too big), an exception is thrown.*/
long findEqualLong(T)(T bignum) {
    enforce(bignum >= -long.max - 1 && bignum <= long.max,
        "Can't convert a number this big to a long.");
    return findEqualLong(bignum, -long.max - 1L, long.max);
}

long findEqualLong(T)(T bignum, long lowerLim, long upperLim) {
    long middle = roundTo!long( 0.5L * lowerLim + 0.5L * upperLim);
    if(bignum == middle) {
        return middle;
    } else if(middle < bignum) {
        return findEqualLong(bignum, middle, upperLim);
    } else if(middle > bignum) {
        return findEqualLong(bignum, lowerLim, middle);
    }
    assert(0);
}

unittest {
    assert(findEqualLong( BigInt(long.max)) == long.max);
    assert(findEqualLong( BigInt(31415)) == 31415);

    writeln("Passed findEqualLong unittest.");
}
