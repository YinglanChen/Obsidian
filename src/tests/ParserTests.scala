package tests

import org.scalatest.junit.JUnitSuite
import org.junit.Test
import Lexer._
import Parser._

class ParserTests extends JUnitSuite {

    private def parse(src : String) : Either[String, AST] = {
        val tokens : Seq[Token] = Lexer.tokenize(src) match {
            case Left(msg) => {
                println(s"Lexing Failed: $msg")
                assert(false)
                return Left("Doesn't lex")
            }
            case Right(res) => res
        }
        Parser.parseAST(tokens)
    }

    private def shouldSucceed(src : String) : Unit = {
        parse(src) match {
            case Right(_) => ()
            case Left(_) => assert(false)
        }
    }
    private def shouldFail(src : String) : Unit = {
        parse(src) match {
            case Right(res) => assert(false)
            case Left(_) => ()
        }
    }

    private def testAndPrint(src : String) : Unit = {
        println(parse(src))
    }

    private def shouldEqual(src : String, ast : AST) : Unit = {
        parse(src) match {
            case Right(res) => assert(res == ast)
            case Left(_) => assert(false)
        }
    }

    private def shouldEqual(src1 : String, src2 : String) : Unit = {
        (Lexer.tokenize(src1), Lexer.tokenize(src2)) match {
            case (Right(res1), Right(res2)) => assert(res1 == res2)
            case _ => ()
        }
    }

    @Test def simpleContracts() = {
        shouldSucceed(
            """
              | contract C { transaction f() { hello = 1; world = 2; } }
            """.stripMargin)
        shouldSucceed(
            """
              | contract C {
              |     state S1 { }
              | }
            """.stripMargin)
    }

    @Test def goodExpressions() = {
        shouldSucceed(
            """
              | contract C {
              |     state S1 {
              |         transaction t1() {
              |             x = (x.f.y.z((((5)))));
              |             (x).f = (new A()).f;
              |         }
              |     }
              | }
            """.stripMargin
        )
    }

    @Test def goodStatements() = {
        shouldSucceed(
            """
              | contract C {
              |     state S1 {
              |         transaction t1() {
              |             x.x = x.f1.f2.f3();
              |             x = x();
              |             x();
              |             x().f = x();
              |             x.f();
              |             x.f.f();
              |             new A();
              |             a = new A();
              |             A a = new A();
              |             T x;
              |             T x = x;
              |             T x = x.f();
              |             return;
              |             return x;
              |             return x.f;
              |         }
              |     }
              | }
            """.stripMargin
        )
    }

    @Test def badStatements() = {
        shouldFail("""contract C { state S { transaction t() {
              | new;
              | }}}""".stripMargin)
        shouldFail("""contract C { state S { transaction t() {
              | return (;
              | }}}""".stripMargin)
    }

    @Test def goodFuncArgs() = {
        shouldSucceed(
            """
              | contract C {
              |     state S1 {
              |         function f() { return x; }
              |         function f(T x) { return x; }
              |         function f(T1 x, linear T2 y, T3 z) { return x; }
              |
              |         transaction t() { return x; }
              |         transaction t(T x) { return x; }
              |         transaction t(T1 x, linear T2 y, T3 z) {
              |             f(x, y, z);
              |             f();
              |             x.f(x, y, z);
              |             f(x);
              |             f(x.f);
              |             f(5, x, f());
              |             f(g(g(5)));
              |         }
              |     }
              | }
            """.stripMargin
        )
    }

    @Test def badFuncArgs() = {
        shouldFail("""contract C { state S {
              | transaction t(x) { return x; }
              | }}""".stripMargin)
        shouldFail("""contract C { state S {
              | function t(x) { return x; }
              | }}""".stripMargin)
        shouldFail("""contract C { state S {
              | transaction t(x, T x) { return x; }
              | }}""".stripMargin)
        shouldFail("""contract C { state S { transaction t() {
              | f(T x);
              | }}}""".stripMargin)
    }
}