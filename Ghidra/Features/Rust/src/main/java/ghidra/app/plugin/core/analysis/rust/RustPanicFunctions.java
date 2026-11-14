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

import java.util.Set;

/**
 * Classifies demangled Rust function paths that never return: the panic entry points of
 * {@code core}, {@code alloc} and {@code std}.
 */
public class RustPanicFunctions {

	private static final Set<String> NORETURN = Set.of(
		"core::panicking::panic",
		"core::panicking::panic_fmt",
		"core::panicking::panic_str",
		"core::panicking::panic_display",
		"core::panicking::panic_explicit",
		"core::panicking::panic_bounds_check",
		"core::panicking::panic_nounwind",
		"core::panicking::panic_nounwind_fmt",
		"core::panicking::panic_nounwind_nobacktrace",
		"core::panicking::panic_cannot_unwind",
		"core::panicking::panic_in_cleanup",
		"core::panicking::panic_misaligned_pointer_dereference",
		"core::panicking::unreachable_display",
		"core::panicking::assert_failed",
		"core::panicking::assert_failed_inner",
		"core::option::expect_failed",
		"core::option::unwrap_failed",
		"core::result::unwrap_failed",
		"core::slice::index::slice_start_index_len_fail",
		"core::slice::index::slice_end_index_len_fail",
		"core::slice::index::slice_index_order_fail",
		"core::slice::index::slice_start_index_overflow_fail",
		"core::slice::index::slice_end_index_overflow_fail",
		"core::str::slice_error_fail",
		"core::cell::panic_already_borrowed",
		"core::cell::panic_already_mutably_borrowed",
		"alloc::raw_vec::capacity_overflow",
		"alloc::raw_vec::handle_error",
		"alloc::alloc::handle_alloc_error",
		"alloc::alloc::__rdl_oom",
		"std::panicking::begin_panic",
		"std::panicking::begin_panic_handler",
		"std::panicking::rust_panic_with_hook",
		"std::panicking::rust_panic_without_hook",
		"std::process::abort",
		"std::rt::begin_panic",
		"rust_begin_unwind",
		"rust_panic");

	/** {@code core::panicking::panic_const::panic_const_add_overflow} and friends */
	private static final String PANIC_CONST_PREFIX = "core::panicking::panic_const::";

	private RustPanicFunctions() {
		// utility
	}

	/**
	 * Removes generic argument lists ({@code <...>}, nested) and a trailing parameter list from a
	 * qualified name, so {@code core::result::unwrap_failed<T,E>(void)} compares equal to
	 * {@code core::result::unwrap_failed}.
	 *
	 * @param name a demangled or namespace-qualified function name
	 * @return the name without generics or parameters
	 */
	public static String normalize(String name) {
		if (name == null) {
			return "";
		}
		StringBuilder sb = new StringBuilder(name.length());
		int depth = 0;
		for (int i = 0; i < name.length(); i++) {
			char c = name.charAt(i);
			if (c == '<') {
				depth++;
			}
			else if (c == '>') {
				if (depth > 0) {
					depth--;
				}
			}
			else if (depth == 0) {
				if (c == '(') {
					break;
				}
				sb.append(c);
			}
		}
		return sb.toString().trim();
	}

	/**
	 * Checks whether the given function path is a known non-returning panic entry point
	 *
	 * @param qualifiedName the namespace-qualified function name
	 * @return true if calls to it never return
	 */
	public static boolean isPanicFunction(String qualifiedName) {
		String name = normalize(qualifiedName);
		if (NORETURN.contains(name)) {
			return true;
		}
		return name.startsWith(PANIC_CONST_PREFIX) && name.length() > PANIC_CONST_PREFIX.length();
	}
}
