using System;
using System.Collections.Generic;
using System.Text;

namespace Huddled.Huddle
{
   /// <summary>
   /// A "Natural Sort" for .NET
   /// 
   /// Copyright (c) 2006, Joel Bennett
   /// 
   /// Permission is hereby granted, free of charge, to any person obtaining a copy 
   /// of this software and associated documentation files (the "Software"), to 
   /// deal in the Software without restriction, including without limitation the 
   /// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
   /// sell copies of the Software, and to permit persons to whom the Software is 
   /// furnished to do so, subject to the following conditions:
   ///
   /// The above copyright notice and this permission notice shall be included in all 
   /// copies or substantial portions of the Software.
   /// 
   /// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
   /// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
   /// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
   /// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
   /// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
   /// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
   /// IN THE SOFTWARE.
   /// </summary>
   public class StringNaturalComparer :StringComparer
   {
      // the string comparison
      private StringComparison comparison;

      #region static instance getters
      private static StringNaturalComparer naturalCurrentCulture;
      private static StringNaturalComparer naturalCurrentCultureIgnoreCase;
      private static StringNaturalComparer naturalInvariantCulture;
      private static StringNaturalComparer naturalInvariantCultureIgnoreCase;
      private static StringNaturalComparer naturalOrdinal;
      private static StringNaturalComparer naturalOrdinalIgnoreCase;

      public static StringNaturalComparer NaturalCurrentCulture
      {
         get
         {
            if( null == naturalCurrentCulture ) {
               naturalCurrentCulture = new StringNaturalComparer( StringComparison.CurrentCulture );
            }
            return naturalCurrentCulture;
         }
      }
      public static StringNaturalComparer NaturalCurrentCultureIgnoreCase
      {
         get
         {
            if( null == naturalCurrentCulture ) {
               naturalCurrentCulture = new StringNaturalComparer( StringComparison.CurrentCultureIgnoreCase );
            }
            return naturalCurrentCulture;
         }
      }
      public static StringNaturalComparer NaturalInvariantCulture
      {
         get
         {
            if( null == naturalCurrentCulture ) {
               naturalCurrentCulture = new StringNaturalComparer( StringComparison.InvariantCulture );
            }
            return naturalCurrentCulture;
         }
      }
      public static StringNaturalComparer NaturalInvariantCultureIgnoreCase
      {
         get
         {
            if( null == naturalCurrentCulture ) {
               naturalCurrentCulture = new StringNaturalComparer( StringComparison.InvariantCultureIgnoreCase );
            }
            return naturalCurrentCulture;
         }
      }
      public static StringNaturalComparer NaturalOrdinal
      {
         get
         {
            if( null == naturalCurrentCulture ) {
               naturalCurrentCulture = new StringNaturalComparer( StringComparison.Ordinal );
            }
            return naturalCurrentCulture;
         }
      }
      public static StringNaturalComparer NaturalOrdinalIgnoreCase
      {
         get
         {
            if( null == naturalCurrentCulture ) {
               naturalCurrentCulture = new StringNaturalComparer( StringComparison.OrdinalIgnoreCase );
            }
            return naturalCurrentCulture;
         }
      }      
      #endregion

      public StringNaturalComparer( StringComparison comparison )
      {
         this.comparison = comparison;
      }

      /// <summary>
      /// Compares two strings using natural numerical ordering
      /// </summary>
      /// <param name="one">The first string</param>
      /// <param name="two">The second string</param>
      /// <returns>A signed number indicating the relative values of this instance and the value parameter. 
      /// <list type="table">
      ///   <listheader>
      ///      <term>Return Value</term>
      ///      <description>Description</description>
      ///   </listheader>
      ///   <item>
      ///      <term>Less than zero</term>
      ///      <description>The first string is less than the second string</description>
      ///   </item>
      ///   <item>
      ///      <term>Zero</term>
      ///      <description>The two strings are equal</description>
      ///   </item>
      ///   <item>
      ///      <term>Greater than zero</term>
      ///      <description>The first string is greater than the second string</description>
      ///   </item>
      /// </list>
      /// <remarks>
      /// Please note I use a char comparison here, I have not yet run into
      /// any problems with this, but it *is* possible that it should be 
      /// converted to a Unicode Locale-aware string comparison. 
      /// </remarks>
      public override int Compare( string one, string two )
      {
         int retVal = 0;
         // System.Diagnostics.Trace.WriteLine(one + "," + two);
         if( !String.IsNullOrEmpty( one ) && !String.IsNullOrEmpty( two ) ) {
            int c1 = 0, c2 = 0;
            int len1 = one.Length, len2 = two.Length;
            while( len1 > c1 ) {
               if( !( len2 > c2 ) ) { retVal = 1; break; }

               // IsDigit determines if a Char is a radix-10 digit. (only DecimalDigitNumber)
               // IsNumber determines if a Char is of any numeric Unicode category. (including LetterNumber, or OtherNumber)
               if( char.IsDigit( one[c1] ) ) {
                  if( !( char.IsDigit( two[c2] ) ) ) { retVal = -1; break; }
                  // TakeNumber is also aware of unicode numbers
                  retVal = TakeNumber( one, ref c1 ).CompareTo( TakeNumber( two, ref c2 ) );
                  if( retVal != 0 )
                     break;
               } else if( char.IsDigit( two[c2] ) ) {
                  retVal = 1;
                  break;
               } else {  
                  //    use the locale-aware string compare...
                  retVal = String.Compare( one, c1, two, c2, 1, comparison );
                  if( retVal != 0 )
                     break;
                  ++c1;
                  ++c2;
               }
            }
            if( 0 == retVal && len2 > c2 ) { retVal = -1; };
         }
         return retVal;
      }

      /// <summary>Parse a number of indeterminate length from a string</summary>
      /// <param name="numerical">A string with a number in it</param>
      /// <param name="index">The index to start parsing at (is set to the index of the first non-numerical character - might be beyond the length of the string)</param>
      /// <returns>The number parsed from the string</returns>
      private static int TakeNumber( string numerical, ref int index )
      {
         //// this test is only needed if it's possible to call the method incorrectly
         //if( !char.IsNumber( numerical[index] ) ) {
         //   throw new InvalidOperationException( "Character at index " + index + " of '" + numerical + "' is not numerical" );
         //}

         // make a copy of the starting point
         int start = index;
         while( ++index < numerical.Length && char.IsDigit( numerical[index] ) ) ;
         // If provider is null, the NumberFormatInfo for the current culture is used.
         return int.Parse( numerical.Substring( start, index - start ), null );
      }

      #region Accuracy Test
      /// <summary>
      /// NUnit Test case. (uncomment the attribute)
      ///   Tests the sort method with a simple series of strings, 
      ///   requires manual visual validation of the output
      /// </summary>
      // [Test]
      public static void TestStringComparer()
      {
         string[] correct = { "1one", "2two", "10ten", "12twelve", "20twenty", "(1 file)", "[1 file]", "_1 file_", "=1 file=", "a1b", "a2b", "a10b", "a11b", "b1", "b2b", "b10b", "bat1", "bat2", "bat10", "cat1", "cat2", "cat10" };
         string[] strings = new string[correct.Length];
         correct.CopyTo( strings, 0 );

         Console.WriteLine( "Before Sort, they're actually in order." );
         foreach( string s in strings )
            Console.WriteLine( s );

         Array.Sort<string>( strings, StringComparer.CurrentCultureIgnoreCase );

         Console.WriteLine();
         Console.WriteLine( "After the default sort, they're in the wrong order." );
         foreach( string s in strings )
            Console.WriteLine( s );


         Array.Sort<string>( strings, StringNaturalComparer.NaturalCurrentCultureIgnoreCase );

         Console.WriteLine();
         Console.WriteLine( "After my sort, they're back in the correct order." );
         foreach( string s in strings )
            Console.WriteLine( s );

         for( int s = 0; s < strings.Length; ++s ) {
            // Assert.AreEqual( correct[s], strings[s], "Strings aren't sorted into the correct order" );
            if( !correct[s].Equals( strings[s] ) ) {
               Console.WriteLine( "ERROR at position " + s + ", " + strings[s] + " is out of order." );
               break;
            }
         }

      }
      
      #endregion
      #region Performance Test

      ///// <summary>
      ///// NUnit Test case. (uncomment the attribute)
      /////   Tests the sort method with a simple series of strings to test the performance
      /////   With 9 * 100k comparisons in two tests:
      ///// </summary>
      ///// <remarks>
      /////   Your results may vary, but just for the sake of comparison, on my computer:
      ///// 
      /////   With numerical strings:
      /////   Using my compare: 00:00:02.6407095
      /////   Using StringCompare: 00:00:00.1093785
      /////   Using StrCmpLogicalW: 00:00:06.6095865
      /////
      /////   With non-numerical strings:
      /////   Using my compare: 00:00:00.5937690
      /////   Using StringCompare: 00:00:00.1093785
      /////   Using StrCmpLogicalW: 00:00:06.6095865
      ///// </remarks>
      //// [Test]
      //public static void PerformanceComparison()
      //{
      //   DateTime end, start;
      //   string one, two, three;
      //   StringNaturalComparer natural = new StringNaturalComparer( StringComparison.InvariantCultureIgnoreCase );
      //   StringComparer builtin = StringComparer.InvariantCultureIgnoreCase;

      //   one = "simple 10 test";
      //   two = "simple 20 test";
      //   three = "simple 03 test";
      //   #region comparisons

      //   start = DateTime.Now;
      //   for( int i = 0; i < 100000; ++i ) {
      //      natural.Compare( one, one );
      //      natural.Compare( one, two );
      //      natural.Compare( one, three );
      //      natural.Compare( two, one );
      //      natural.Compare( two, two );
      //      natural.Compare( two, three );
      //      natural.Compare( three, one );
      //      natural.Compare( three, two );
      //      natural.Compare( three, three );
      //   }
      //   end = DateTime.Now;

      //   Console.WriteLine( "Using my compare: " + (TimeSpan)( end - start ) );

      //   start = DateTime.Now;
      //   for( int i = 0; i < 100000; ++i ) {
      //      builtin.Compare( one, one );
      //      builtin.Compare( one, two );
      //      builtin.Compare( one, three );
      //      builtin.Compare( two, one );
      //      builtin.Compare( two, two );
      //      builtin.Compare( two, three );
      //      builtin.Compare( three, one );
      //      builtin.Compare( three, two );
      //      builtin.Compare( three, three );
      //   }
      //   end = DateTime.Now;

      //   Console.WriteLine( "Using StringCompare: " + (TimeSpan)( end - start ) );


      //   start = DateTime.Now;
      //   for( int i = 0; i < 100000; ++i ) {
      //      StrCmpLogicalW( one, one );
      //      StrCmpLogicalW( one, two );
      //      StrCmpLogicalW( one, three );
      //      StrCmpLogicalW( two, one );
      //      StrCmpLogicalW( two, two );
      //      StrCmpLogicalW( two, three );
      //      StrCmpLogicalW( three, one );
      //      StrCmpLogicalW( three, two );
      //      StrCmpLogicalW( three, three );
      //   }
      //   end = DateTime.Now;
      //   Console.WriteLine( "Using StrCmpLogicalW: " + (TimeSpan)( end - start ) );
      //   #endregion

      //   one = "This is a simple string without numbers";
      //   two = "Test";
      //   three = "This is another one with no numbers";
      //   #region comparisons

      //   start = DateTime.Now;
      //   for( int i = 0; i < 100000; ++i ) {
      //      natural.Compare( one, one );
      //      natural.Compare( one, two );
      //      natural.Compare( one, three );
      //      natural.Compare( two, one );
      //      natural.Compare( two, two );
      //      natural.Compare( two, three );
      //      natural.Compare( three, one );
      //      natural.Compare( three, two );
      //      natural.Compare( three, three );
      //   }
      //   end = DateTime.Now;

      //   Console.WriteLine( "Using my compare: " + (TimeSpan)( end - start ) );

      //   start = DateTime.Now;
      //   for( int i = 0; i < 100000; ++i ) {
      //      builtin.Compare( one, one );
      //      builtin.Compare( one, two );
      //      builtin.Compare( one, three );
      //      builtin.Compare( two, one );
      //      builtin.Compare( two, two );
      //      builtin.Compare( two, three );
      //      builtin.Compare( three, one );
      //      builtin.Compare( three, two );
      //      builtin.Compare( three, three );
      //   }
      //   end = DateTime.Now;

      //   Console.WriteLine( "Using StringCompare: " + (TimeSpan)( end - start ) );


      //   start = DateTime.Now;
      //   for( int i = 0; i < 100000; ++i ) {
      //      StrCmpLogicalW( one, one );
      //      StrCmpLogicalW( one, two );
      //      StrCmpLogicalW( one, three );
      //      StrCmpLogicalW( two, one );
      //      StrCmpLogicalW( two, two );
      //      StrCmpLogicalW( two, three );
      //      StrCmpLogicalW( three, one );
      //      StrCmpLogicalW( three, two );
      //      StrCmpLogicalW( three, three );
      //   }
      //   end = DateTime.Now;
      //   Console.WriteLine( "Using StrCmpLogicalW: " + (TimeSpan)( end - start ) );
      //   #endregion

      //}

      [System.Runtime.InteropServices.DllImport( "shlwapi.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, ExactSpelling = true, SetLastError = false )]
      private static extern int StrCmpLogicalW( string strA, string strB );
      
      #endregion

      public override bool Equals( string x, string y )
      {
         return x.Equals( y );
      }

      public override int GetHashCode( string obj )
      {
         return obj.GetHashCode();
      }
   }
}
