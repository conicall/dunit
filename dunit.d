module dunit;

import std.stdio;

string[] testClasses;
string[][string] testNamesByClass;
void function(Object o, string testName)[string] testCallers;
Object function()[string] testCreators;

public static void runTests() {
    //List Test classes:
    writeln("Unit tests: ");
    foreach (string className; testClasses) {
        writeln("    " ~ className);

        //Create the class:
        Object testObject = null;
        try {
            testObject = testCreators[className]();
        } catch (Throwable t) {
            writeln("        ERROR IN CONSTRUCTOR: " ~ className ~ ".this(): " ~ t.toString());
        }
        if (testObject is null) {
            continue;
        }

        //Run each test of the class:
        foreach (string testName; testNamesByClass[className]) {
            try {
                testCallers[className](testObject, testName);
                writeln("        OK: " ~ testName ~ "()");
            } catch (Throwable t) {
                writeln("        ERROR: " ~ testName ~ "(): " ~ t.toString());
            }
        }
    }
}

public static immutable(string[]) _testMethodsArray(S...)(S args) pure nothrow {
    static if (args.length == 0) {
        return [];
    }

    //Skip strings that don't start with "test":
    immutable str = args[0];
    if (str.length < 4 || str[0..4] != "test") {
        static if(args.length == 1) {
            return [];
        } else {
            return _testMethodsArray(args[1..$]);
        }
    }

    //Return the first argument and the rest:
    static if (args.length == 1) {
        return [args[0]];
    } else {
        static if (args.length > 1) {
            return [args[0]] ~ _testMethodsArray(args[1..$]);
        } else {
            return [];
        }
    }
}

public static T _createClassObject(T)() {
    return new T();
}

mixin template TestMixin() {

    public static this() {

        //Names of test methods:
        immutable t = __traits(derivedMembers, __traits(parent, _testClass_));
        immutable(string[]) _testMethods = _testMethodsArray(t);

        //@factory method
        //@switch(testmethodName) { case "test1": refObj.test1(); }
        //@register: struct {className, factoryMethodPointer, runMethodPointer}
        //.fixtureSetup
        //.fixtureTeardown
        //.setup
        //.tearDown
        //.unittest that derive unittests.
        //.var names that start with 'test'.
        //.'test' methods with arguments.
        //.'test' methods with overloads.

        //Factory method:
        static Object createFunction() { 
            return _createClassObject!(__traits(parent, _testClass_))(); 
        }

        //Run method:
        //Generate a switch statement, that calls the method that matches the testName:
        static void runTest(Object o, string testName) {
            mixin(
                genRunTest(__traits(parent, _testClass_).stringof, 
                           __traits(derivedMembers, __traits(parent, _testClass_)))
            );
        }

        //Register UnitTest class:
        string className = __traits(parent, _testClass_).stringof;
        testClasses ~= className;
        testNamesByClass[className] = _testMethods.dup;
        testCallers[className] = &runTest;
        testCreators[className] = &createFunction;
    }

    /** Generates the function that runs a method from its name. */
    private static string genRunTest(S...)(string s, S args) pure nothrow {
        return 
            s ~ " testObject = cast("~s~")o;"
            ~"switch (testName) {"
            ~genRunTestImpl(args)
            ~"    default: break;"
            ~"}";
    }
    /** Generates the case statements. */
    private static string genRunTestImpl(S...)(S args) pure nothrow {
        static if (args.length == 0) {
            return "";
        }

        //Skip method names that don't start with 'test':
        if (args[0].length < 4 || args[0][0..4] != "test") {
            static if (args.length == 1) {
                return "";
            } else {
                return genRunTestImpl(args[1..$]);
            }
        }

        static if (args.length == 1) {
            return "case \"" ~ args[0] ~ "\": testObject." ~ args[0] ~ "(); break;";
        } else {
            return "case \"" ~ args[0] ~ "\": testObject." ~ args[0] ~ "(); break;"
                ~ genRunTestImpl(args[1..$]);
        }
    }

    private static void _testClass_() {
    }
}