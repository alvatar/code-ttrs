/************************
Author: Benjamin Shropshire

This is a unit bearing type that handles unit conversion and uses compile time 
checks to protect against errors like adding distance and time value.
************************/



import std.stdio;
import std.math;
import std.traits;

import rational;

template T(Tp...){alias Tp T;}

version(FullSI)
{

	private alias T!(0,0) extra;
	private alias T!(0,1,0,1) extra2;

	template Batch(
				int LengthN,  int LengthD,
				int MassN,    int MassD,
				int TimeN,    int TimeD,
				int TempN,    int TempD,
				int CurrentN, int CurrentD,
				int LumiN,    int LumiD,
				int MoleN,    int MoleD
				)
	{
		// sanity check
		static assert (Reduce!(LengthN,  LengthD).Reduced, "Length must be in reduced form");
		static assert (Reduce!(MassN,    MassD).Reduced,   "Mass must be in reduced form");
		static assert (Reduce!(TimeN,    TimeD).Reduced,   "Time must be in reduced form");
		static assert (Reduce!(TempN,    TempD).Reduced,   "Temp must be in reduced form");
		static assert (Reduce!(CurrentN, CurrentD).Reduced,"Current must be in reduced form");
		static assert (Reduce!(LumiN,    LumiD).Reduced,   "Luminous intensity must be in reduced form");
		static assert (Reduce!(MoleN,    MoleD).Reduced,   "Quantity must be in reduced form");

		/// visable units
		enum LenN = LengthN,  LenD = LengthD;
		enum MasN = MassN,    MasD = MassD;		///
		enum TimN = TimeN,    TimD = TimeD;		///
		enum TmpN = TempN,    TmpD = TempD;		///
		enum CurN = CurrentN, CurD = CurrentD;	///
		enum LumN = LumiN,    LumD = LumiD;		///
		enum MolN = MoleN,    MolD = MoleD;		///
	}

	template SI(int LengthN, int MassN, int TimeN, int TempN, int CurrentN, int LumiN, int MoleN, T = real)
	{
		alias SIB!(Batch!(
				/// visable units
				LengthN,  1,
				MassN,    1,
				TimeN,    1,
				TempN,    1,
				CurrentN, 1,
				LumiN,    1,
				MoleN,    1
				), T) SI;
	}
	template SI(
				int LengthN,  int LengthD,
				int MassN,    int MassD,
				int TimeN,    int TimeD,
				int TempN,    int TempD,
				int CurrentN, int CurrentD,
				int LuminN,   int LuminD,
				int MoleN,    int MoleD,
				T = real
				)
	{
		alias SIB!(Batch!(
				/// visable units
				LengthN,  LengthD, 
				MassN,    MassD,
				TimeN,    TimeD,
				TempN,    TempD,
				CurrentN, CurrentD,
				LuminN,   LuminD,
				MoleN,    MoleD
				), T ) SI;
	}
}
else
{
	private alias T!() extra;
	private alias T!() extra2;
	template Batch(
				int LengthN,  int LengthD,
				int MassN,    int MassD,
				int TimeN,    int TimeD,
				int TempN,    int TempD,
				int CurrentN, int CurrentD
				)
	{
		// sanity check
		static assert (Reduce!(LengthN,  LengthD).Reduced, "Length must be in reduced form");
		static assert (Reduce!(MassN,    MassD).Reduced,   "Mass must be in reduced form");
		static assert (Reduce!(TimeN,    TimeD).Reduced,   "Time must be in reduced form");
		static assert (Reduce!(TempN,    TempD).Reduced,   "Temp must be in reduced form");
		static assert (Reduce!(CurrentN, CurrentD).Reduced,"Current must be in reduced form");

		/// visable units
		enum LenN = LengthN,  LenD = LengthD;
		enum MasN = MassN,    MasD = MassD;		///
		enum TimN = TimeN,    TimD = TimeD;		///
		enum TmpN = TempN,    TmpD = TempD;		///
		enum CurN = CurrentN, CurD = CurrentD;	///
	}

	template SI(int LengthN, int MassN, int TimeN, int TempN, int CurrentN, T = real)
	{
		alias SIB!(Batch!(
				/// visable units
				LengthN,  1,
				MassN,    1,
				TimeN,    1,
				TempN,    1,
				CurrentN, 1
				), T ) SI;
	}
	template SI(
				int LengthN,  int LengthD,
				int MassN,    int MassD,
				int TimeN,    int TimeD,
				int TempN,    int TempD,
				int CurrentN, int CurrentD,
				T = real
				)
	{

		alias SIB!(Batch!(
				/// visable units
				LengthN,  LengthD,
				MassN,    MassD,
				TimeN,    TimeD,
				TempN,    TempD,
				CurrentN, CurrentD
				), T ) SI;
	}
}
struct SIB(alias Exp_, U)
{

	alias Exp_ Exp;


	// generate a usable name string
	static if(Exp.LenD == 1) private enum sLen = Exp.LenN.stringof; else private enum sLen = Exp.LenN.stringof~"/"~Exp.LenD.stringof;
	static if(Exp.MasD == 1) private enum sMas = Exp.MasN.stringof; else private enum sMas = Exp.MasN.stringof~"/"~Exp.MasD.stringof;
	static if(Exp.TimD == 1) private enum sTim = Exp.TimN.stringof; else private enum sTim = Exp.TimN.stringof~"/"~Exp.TimD.stringof;
	static if(Exp.TmpD == 1) private enum sTmp = Exp.TmpN.stringof; else private enum sTmp = Exp.TmpN.stringof~"/"~Exp.TmpD.stringof;
	static if(Exp.CurD == 1) private enum sCur = Exp.CurN.stringof; else private enum sCur = Exp.CurN.stringof~"/"~Exp.CurD.stringof;
	/// The type name
	version(FullSI)	
	{
	static if(Exp.LumD == 1) private enum sLum = Exp.LumN.stringof; else private enum sLum = Exp.LumN.stringof~"/"~Exp.LumD.stringof;
	static if(Exp.MolD == 1) private enum sMol = Exp.MolN.stringof; else private enum sMol = Exp.MolN.stringof~"/"~Exp.MolD.stringof;
	public enum Stringof = "SI!("~sLen~","~sMas~","~sTim~","~sTmp~","~sCur~","~sLum~","~sMol~","~U.stringof~")";
	}
	else public enum Stringof = "SI!("~sLen~","~sMas~","~sTim~","~sTmp~","~sCur~","~U.stringof~")";

	/// the value
	private U value;

	/// a more meaningful name
	private alias SIB This;

	// check to make shure it's right!
	static assert(is(SIB!(Exp,U) == This));

	template Using(V) { alias SIB!(Exp,V) Using; }

	template Alike2(V)
	{
		version(FullSI) enum bool Alike2 = 
					Exp.LumN == V.Exp.LumN && Exp.LumD == V.Exp.LumD &&
					Exp.MolN == V.Exp.MolN && Exp.MolD == V.Exp.MolD;
		else enum bool Alike2 = true;
	}
	template Alike(V)
	{
		enum bool Alike = Alike2!(V) &&
			Exp.LenN == V.Exp.LenN && Exp.LenD == V.Exp.LenD &&
			Exp.MasN == V.Exp.MasN && Exp.MasD == V.Exp.MasD &&
			Exp.TimN == V.Exp.TimN && Exp.TimD == V.Exp.TimD &&
			Exp.TmpN == V.Exp.TmpN && Exp.TmpD == V.Exp.TmpD &&
			Exp.CurN == V.Exp.CurN && Exp.CurD == V.Exp.CurD;
	}


	/// find the type of "This * T"
	private template Mul2(U)
	{
		version(FullSI) alias T!(
				Reduce!(Exp.LumN*U.Exp.LumD + Exp.LumD*U.Exp.LumN, Exp.LumD*U.Exp.LumD).V,
				Reduce!(Exp.MolN*U.Exp.MolD + Exp.MolD*U.Exp.MolN, Exp.MolD*U.Exp.MolD).V) Mul2;
		else alias T!() Mul2;
	}
	private template Mul(T)
	{
		static if(is(T : U))
			alias This Mul;
		else
			alias SIB!(Batch!(
						Reduce!(Exp.LenN*T.Exp.LenD + Exp.LenD*T.Exp.LenN, Exp.LenD*T.Exp.LenD).V,
						Reduce!(Exp.MasN*T.Exp.MasD + Exp.MasD*T.Exp.MasN, Exp.MasD*T.Exp.MasD).V,
						Reduce!(Exp.TimN*T.Exp.TimD + Exp.TimD*T.Exp.TimN, Exp.TimD*T.Exp.TimD).V,
						Reduce!(Exp.TmpN*T.Exp.TmpD + Exp.TmpD*T.Exp.TmpN, Exp.TmpD*T.Exp.TmpD).V,
						Reduce!(Exp.CurN*T.Exp.CurD + Exp.CurD*T.Exp.CurN, Exp.CurD*T.Exp.CurD).V,
						Mul2!(T)),
						U
					) Mul;
	}

	/// find the type of "This / T"
	private template Div2(U)
	{
		version(FullSI) alias T!(
				Reduce!(Exp.LumN*U.Exp.LumD - Exp.LumD*U.Exp.LumN, Exp.LumD*U.Exp.LumD).V,
				Reduce!(Exp.MolN*U.Exp.MolD - Exp.MolD*U.Exp.MolN, Exp.MolD*U.Exp.MolD).V) Div2;
		else alias T!() Div2;
	}
	private template Div(T)
	{
		static if(is(T : U))
			alias This Div;
		else
			alias SIB!(Batch!(
						Reduce!(Exp.LenN*T.Exp.LenD - Exp.LenD*T.Exp.LenN, Exp.LenD*T.Exp.LenD).V,
						Reduce!(Exp.MasN*T.Exp.MasD - Exp.MasD*T.Exp.MasN, Exp.MasD*T.Exp.MasD).V,
						Reduce!(Exp.TimN*T.Exp.TimD - Exp.TimD*T.Exp.TimN, Exp.TimD*T.Exp.TimD).V,
						Reduce!(Exp.TmpN*T.Exp.TmpD - Exp.TmpD*T.Exp.TmpN, Exp.TmpD*T.Exp.TmpD).V,
						Reduce!(Exp.CurN*T.Exp.CurD - Exp.CurD*T.Exp.CurN, Exp.CurD*T.Exp.CurD).V,
						Div2!(T)),
						U
					) Div;
	}

	/// find the type of "This ^ 1/i"
	private template Root2(int i)
	{
		version(FullSI) alias T!(
				Reduce!(Exp.LumN,Exp.LumD*i).V,
				Reduce!(Exp.MolN,Exp.MolD*i).V) Root2;
		else alias T!() Root2;
	}
	private static template RootT(int i)
	{
		alias SIB!(Batch!(
			Reduce!(Exp.LenN, Exp.LenD*i).V,
			Reduce!(Exp.MasN, Exp.MasD*i).V,
			Reduce!(Exp.TimN, Exp.TimD*i).V,
			Reduce!(Exp.TmpN, Exp.TmpD*i).V,
			Reduce!(Exp.CurN, Exp.CurD*i).V,
			Root2!(i)
			),
			U) RootT;
	}

	/// find the type of "This ^ i"
	private template Power2(int i)
	{
		version(FullSI) alias T!(
				Reduce!(Exp.LumN*i,Exp.LumD).V,
				Reduce!(Exp.MolN*i,Exp.MolD).V) Power2;
		else alias T!() Power2;
	}
	private template Power(int i)
	{
		alias SIB!(Batch!(
			Reduce!(Exp.LenN*i, Exp.LenD).V,
			Reduce!(Exp.MasN*i, Exp.MasD).V,
			Reduce!(Exp.TimN*i, Exp.TimD).V,
			Reduce!(Exp.TmpN*i, Exp.TmpD).V,
			Reduce!(Exp.CurN*i, Exp.CurD).V,
			Power2!(i)
			),
			U) Power;
	}

	// I don't think I need this anymore
	//This opCall(This ret) { return ret; }


	private this(U u) { value = u; }

	int opCmp(This that) 
	{
		if(this.value < that.value) return -1;
		if(this.value > that.value) return +1;
		return 0;
	}

	int opCmp(U that) 
	{
		if(this.value < that) return -1;
		if(this.value > that) return +1;
		return 0;
	}

	/// Homomorphic math operators
	This opNeg() { return This(- this.value);}
	This opPos() { return this; }	///

	This opAdd(This that) { return This(this.value + that.value);}	///
	This opSub(This that) { return This(this.value - that.value);}	///
	This opAddAssign(This that) { this.value += that.value; return this; }	///
	This opSubAssign(This that) { this.value -= that.value; return this; }	///

	This opMulAssign(U r) { this.value *= r; return this; }
	This opDivAssign(U r) { this.value /= r; return this; }	///
	
	This opMul_r(U that) { return This(this.value * that); }	///

		/// non-Homomorphic math operators
	auto opDiv_r(U that) { return Power!(-1)(that / this.value); }	///

	version(FullSI) private enum unitless2 = Exp.LumN == 0 && Exp.MolN == 0;
	else private enum unitless2 = true;
	static if(Exp.LenN == 0 && Exp.MasN == 0 && Exp.TimN == 0 && Exp.TmpN == 0 && Exp.CurN == 0 && unitless2)
		alias value this;
	else
	{
		// these conflict if the "alias value this" is in effect

		/// non-Homomorphic math operators
		auto opMul(T)(T that)
		{
			static if(is(T : U)) return Mul!(T)(this.value * that);
			else return Mul!(T)(this.value * that.value);
		}
		auto opDiv(T)(T that)	///
		{
			static if(is(T : U)) return Div!(T)(this.value / that);
			else return Div!(T)(this.value / that.value);
		}
	}

	/// test if these are close enough
	bool Near(This that, int count = 5)
	{
		static if(isFloatingPoint!(U))
			return std.math.feqrel!(U)(this.value,that.value) + count >= U.mant_dig;
		else
			return this.value == that.value;
	}

	/// common math functions
	auto Root(int i)(){return RootT!(i)(std.math.sqrt(this.value));}
	auto Pow(int i)(){return Power!(i)(std.math.pow(this.value,i));}	///
	This Abs() { return This(std.math.abs(this.value)); }	///


	/// convert to real from type "s"
	U opDispatch(string s)()
	{
		static if(!is(Unit!(s).type)) static assert(false, "SI has no member named "~s~" nor is it a known type");
		else
		{
			static assert(This.Alike!(Unit!(s).type), "Can't convert type "~This.Stringof~" to \""~s~"\" of type "~Unit!(s).type.Stringof);
			return value / Unit!(s).mul;
		}
	}

}

/// convert from real to type "s"
struct OfType
{
	static auto opDispatch(string s, U)(U v) ///
	{
		static if(!is(Unit!(s).type)) static assert(false, "OfType."~s~" is not a known type");
		else return Unit!(s).type.Using!(U)(cast(U)(v * Unit!(s).mul));
	}
}


/// Basic types
public struct Types
{
	alias SI!( 0, 0, 0, 0, 0, extra) Value;			///
	alias SI!( 1, 0, 0, 0, 0, extra) Distance;		///
	alias SI!( 0, 1, 0, 0, 0, extra) Mass;			///
	alias SI!( 0, 0, 1, 0, 0, extra) Time;			///
	alias SI!( 0, 0, 0, 1, 0, extra) Temp;			///
	alias SI!( 0, 0, 0, 0, 1, extra) Current;		///
	version(FullSI)
	{
	alias SI!( 0, 0, 0, 0, 0, 1, 0) Luminosity;		///
	alias SI!( 0, 0, 0, 0, 0, 0, 1) Quantity;		///
	}

	alias SI!(-3, 1, 0, 0, 0, extra) MassDensity;	///

	alias SI!(-2,-1, 3, 0, 2, extra) Resistance;	///
	alias SI!(-2,-1, 4, 0, 2, extra) Capacitance;	///

	alias SI!(-1, 1,-2, 0, 0, extra) Pressure;		///
	alias SI!(-1, 1,-1, 0, 0, extra) Viscosity;		///

	alias SI!( 0, 0,-1, 0, 0, extra) Frequency;		///
	alias SI!( 0, 0, 1, 0, 1, extra) Charge;		///
	alias SI!( 0, 1,-1, 0, 0, extra) MassFlow;		///
	alias SI!( 0, 1,-2, 0,-1, extra) MagneticFluxD;	///

	alias SI!( 1, 1,-2, 0, 0, extra) Force;			///
	alias SI!( 1, 0,-2, 0, 0, extra) Acceleration;	///
	alias SI!( 1, 0,-1, 0, 0, extra) Speed;			///


	alias SI!( 2, 1,-3, 0,-1, extra) Voltage;		///
	alias SI!( 2, 1,-3, 0, 0, extra) Power;			///
	alias SI!( 2, 1,-2, 0,-2, extra) Inductance;	///
	alias SI!( 2, 1,-2, 0, 0, extra) Energy;		///
	alias SI!( 2, 0, 0, 0, 0, extra) Area;			///
	alias SI!( 2, 0,-1, 0, 0, extra) KViscosity;	///

	alias SI!( 3, 0,-1, 0, 0, extra) VolumeFlow;	///
	alias SI!( 3, 0, 0, 0, 0, extra) Volume;		///
}

/// Some less common types
public struct Engr
{
	///
	public struct Thermal
	{
		alias SI!( 2, 0,-2,-1, 0, extra) ThermalCap;		///
		alias SI!( 1, 1,-3,-1, 0, extra) ThermalCond;		///
		alias SI!( 0, 1,-3,-1, 0, extra) ConvectionCoeff;	///
	}
	///
	public struct FracturMechanics
	{
		alias SI!(-1,2, 1,1,-2,1, 0,1, 0,1, extra2) StressIntensity;///
	}
}

/// Base SI units
template Unit(string name : "value")	{ enum mul = 1.0;				alias Value          type; }
template Unit(string name : "meter")	{ enum mul = 1.0;				alias Types.Distance type; }	///
template Unit(string name : "kilogram")	{ enum mul = 1.0;				alias Types.Mass     type; }	///
template Unit(string name : "second")	{ enum mul = 1.0;				alias Types.Time     type; }	///
template Unit(string name : "kelvin")	{ enum mul = 1.0;				alias Types.Temp     type; }	///
template Unit(string name : "ampere")	{ enum mul = 1.0;				alias Types.Current  type; }	///
version(FullSI)
{
//template Unit(string name : "candela")	{ enum mul = 1.0;				alias Types.Luminosity type; }	/// This one is named wrong
template Unit(string name : "mole")		{ enum mul = 1.0;				alias Types.Quantity   type; }	///
}

/// Distance Unit Types
template Unit(string name : "Angstrom")	{ enum mul = 1e-10;				alias Types.Distance type; }
template Unit(string name : "Micron")	{ enum mul = 1e-6;				alias Types.Distance type; }	///
template Unit(string name : "mm")		{ enum mul = 1e-3;				alias Types.Distance type; }	///
template Unit(string name : "cm")		{ enum mul = 1e-2;				alias Types.Distance type; }	///
template Unit(string name : "km")		{ enum mul = 1e3;				alias Types.Distance type; }	///
template Unit(string name : "inch")		{ enum mul = 2.54e-2;			alias Types.Distance type; }	///
template Unit(string name : "foot")		{ enum mul = 3.04799835e-1;		alias Types.Distance type; }	///
template Unit(string name : "yard")		{ enum mul = 9.14399506e-1;		alias Types.Distance type; }	///
template Unit(string name : "mile")		{ enum mul = 1.609343130e3;		alias Types.Distance type; }	///
template Unit(string name : "parsec")	{ enum mul = 3.085677473598e13;	alias Types.Distance type; }	///

/// Mass Unit Types
template Unit(string name : "gram")		{ enum mul = 1e-3;				alias Types.Mass type; }
template Unit(string name : "lb")		{ enum mul = 4.5359237e-1;		alias Types.Mass type; }	///
template Unit(string name : "Ounce")	{ enum mul = 2.834952e-2;		alias Types.Mass type; }	///

/// Time Unit Types
template Unit(string name : "minute")	{ enum mul = 60.0;				alias Types.Time type; }
template Unit(string name : "hour")		{ enum mul = 3600.0;			alias Types.Time type; }	///
template Unit(string name : "day")		{ enum mul = 86400.0;			alias Types.Time type; }	///

/// Temperature Unit Types
template Unit(string name : "R")		{ enum mul = 0.5555555555;		alias Types.Temp type; }

/// Force  Unit Types
template Unit(string name : "newton")	{ enum mul = 1.0;				alias Types.Force type; }
template Unit(string name : "dyne")		{ enum mul = 1e-5;				alias Types.Force type; }	///
template Unit(string name : "lbf")		{ enum mul = 4.44822246806;		alias Types.Force type; }	///

/// Charge Unit Types
template Unit(string name : "coulomb")	{ enum mul = 1.0;				alias Types.Charge type; }

/// Magnetic flux density
template Unit(string name : "tesla")		{ enum mul = 1.0;				alias Types.MagneticFluxD type; }

/// magnetic flux
template Unit(string name : "weber")		{ enum mul = 1.0;				alias SI!(2,1,-2,0,1) type; }

/// inductance
template Unit(string name : "henry")		{ enum mul = 1.0;				alias Types.Inductance type; }

/// Energy Unit Types
template Unit(string name : "joule")	{ enum mul = 1.0;				alias Types.Energy type; }
template Unit(string name : "Erg")		{ enum mul = 1e-7L;				alias Types.Energy type; }	///
template Unit(string name : "cal")		{ enum mul = 4.1868L;			alias Types.Energy type; }	///
template Unit(string name : "eV")		{ enum mul = 1.602176462e-19L;	alias Types.Energy type; }	///
template Unit(string name : "BTU")		{ enum mul = 1.0550558526e3L;	alias Types.Energy type; }	///

/// Voltage Unit Types
template Unit(string name : "volt")		{ enum mul = 1.0;				alias Types.Voltage type; }

/// Frequency Unit Types
template Unit(string name : "hertz")		{ enum mul = 1.0;				alias Types.Frequency type; }

/// Resistance Unit Types
template Unit(string name : "ohm")		{ enum mul = 1.0;				alias Types.Resistance type; }

/// Pressure Unit Types
template Unit(string name : "pascal")		{ enum mul = 1.0;				alias Types.Pressure type; }
template Unit(string name : "Bar")		{ enum mul = 1e5L;				alias Types.Pressure type; }	///
template Unit(string name : "Atm")		{ enum mul = 1.01325e5L;		alias Types.Pressure type; }	///
template Unit(string name : "psi")		{ enum mul = 6.89475729e3;		alias Types.Pressure type; }	///

/// Viscosity
//
template Unit(string name : "poise")	{ enum mul = 0.1;				alias Types.Viscosity type; }
//
template Unit(string name : "stokes")	{ enum mul = 0.0001;			alias Types.KViscosity type; }

/// Power Unit Types
template Unit(string name : "watt")		{ enum mul = 1.0;				alias Types.Power type; }
template Unit(string name : "kWatt")	{ enum mul = 1000;				alias Types.Power type; }	///
template Unit(string name : "Hp")		{ enum mul = 745.69987158L;		alias Types.Power type; }	///

/// Volume Unit Types
template Unit(string name : "steres")	{ enum mul = 1.0;				alias Types.Volume type; }
template Unit(string name : "litre")	{ enum mul = 0.001L;			alias Types.Volume type; }	///
template Unit(string name : "Gal")		{ enum mul = 0.0037854120L;		alias Types.Volume type; }	///
template Unit(string name : "Cup")		{ enum mul = 0.0002365883L;		alias Types.Volume type; }	///

/// volume rate
template Unit(string name : "gpm")		{ enum mul = 6.30901995e-5L;	alias Types.VolumeFlow type; }
template Unit(string name : "cfm")		{ enum mul = 4.71947443e-4L;	alias Types.VolumeFlow type; }	///

/// Speed Unit Types
template Unit(string name : "mps")		{ enum mul = 1L;				alias Types.Speed type; }
template Unit(string name : "Knots")	{ enum mul = 1.51444L;			alias Types.Speed type; }	///
template Unit(string name : "mph")		{ enum mul = 0.44704L;			alias Types.Speed type; }	///
template Unit(string name : "kph")		{ enum mul = 0.27778L;			alias Types.Speed type; }	///
template Unit(string name : "fps")		{ enum mul = 0.3048L;			alias Types.Speed type; }	///

/// Capacitance Unit Types
template Unit(string name : "farad")	{ enum mul = 1.0;				alias Types.Capacitance type; }

/// Area Unit Types
template Unit(string name : "Acre")		{ enum mul = 4046.856421L;		alias Types.Area type; }

/// Acceleration Unit Types
template Unit(string name : "G")		{ enum mul = 9.80665L;			alias Types.Acceleration type; }

/// alterant names
private:

template Alt(string name : "C")  { enum Alt = "coulomb"; }
template Alt(string name : "N")  { enum Alt = "newton"; }
template Alt(string name : "J")  { enum Alt = "joule"; }
template Alt(string name : "V")  { enum Alt = "volt"; }
template Alt(string name : "Hz") { enum Alt = "hertz"; }
template Alt(string name : "Pa") { enum Alt = "pascal"; }
template Alt(string name : "P")  { enum Alt =" poise"; }
template Alt(string name : "W")  { enum Alt = "watt"; }
template Alt(string name : "L")  { enum Alt = "litre"; }
template Alt(string name : "liter") { enum Alt = "litre"; }
template Alt(string name : "F")  { enum Alt = "farad"; }
template Alt(string name : "H")  { enum Alt = "henry"; }
template Alt(string name : "Wb") { enum Alt = "weber"; }
template Alt(string name : "T")  { enum Alt = "tesla"; }
version(FullSI)
{
template Alt(string name : "mol"){ enum Alt = "mole"; }
template Alt(string name : "cd") { enum Alt = "candela"; }
}

public:

template Unit(string name) { alias Unit!(Alt!(name)) Unit; }


unittest
{
	writef("%s\n", OfType.foot(3.0).meter);

	Types.Distance v;  //pragma(msg,"v:\t"~typeof(v).stringof);

	auto v2 = v * v;  //pragma(msg,"v2:\t"~typeof(v2).stringof);
	auto v3 = v2 / v; //pragma(msg,"v3:\t"~typeof(v3).stringof);
	auto v4 = v / v;  //pragma(msg,"v4:\t"~typeof(v4).stringof);
	real r = v4;
	auto v5 = v4 / v; //pragma(msg,"v5:\t"~typeof(v5).stringof);
	//auto v6a = v2 + v;
	auto v6b = v3 + v;
	auto v7 = v.Root!(2)(); //pragma(msg,"v7:\t"~typeof(v7).stringof);
	auto v8 = v7.Pow!(4)(); //pragma(msg,"v8:\t"~typeof(v8).stringof);

	Engr.FracturMechanics.StressIntensity k;
	auto k2 = k*k;
	auto p = OfType.psi(0.0L);
	k2 = p*p*OfType.foot(3.0L);

	auto newton = OfType.N(5);
}
