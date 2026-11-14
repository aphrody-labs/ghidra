/* ###
 * IP: GHIDRA
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package ghidra.app.plugin.core.analysis.rust;

import static org.junit.Assert.*;

import org.junit.Test;

public class RustPanicFunctionsTest {

	@Test
	public void testKnownPanics() {
		assertTrue(RustPanicFunctions.isPanicFunction("core::panicking::panic"));
		assertTrue(RustPanicFunctions.isPanicFunction("core::panicking::panic_fmt"));
		assertTrue(RustPanicFunctions.isPanicFunction("core::panicking::panic_bounds_check"));
		assertTrue(RustPanicFunctions.isPanicFunction("core::option::expect_failed"));
		assertTrue(RustPanicFunctions.isPanicFunction("alloc::alloc::handle_alloc_error"));
		assertTrue(RustPanicFunctions.isPanicFunction("rust_begin_unwind"));
	}

	@Test
	public void testPanicConst() {
		assertTrue(RustPanicFunctions
				.isPanicFunction("core::panicking::panic_const::panic_const_add_overflow"));
		assertFalse(RustPanicFunctions.isPanicFunction("core::panicking::panic_const::"));
	}

	@Test
	public void testGenericsAndParametersIgnored() {
		assertTrue(RustPanicFunctions
				.isPanicFunction("core::result::unwrap_failed<T,E>(void)"));
		assertTrue(RustPanicFunctions.isPanicFunction(
			"core::panicking::assert_failed<A<B>,C>"));
	}

	@Test
	public void testNonPanics() {
		assertFalse(RustPanicFunctions.isPanicFunction("core::fmt::write"));
		assertFalse(RustPanicFunctions.isPanicFunction("std::panicking::panic_count::increase"));
		assertFalse(RustPanicFunctions.isPanicFunction(""));
		assertFalse(RustPanicFunctions.isPanicFunction(null));
	}

	@Test
	public void testNormalize() {
		assertEquals("a::b", RustPanicFunctions.normalize("a::b<X<Y>>(int)"));
		assertEquals("", RustPanicFunctions.normalize(null));
	}
}
