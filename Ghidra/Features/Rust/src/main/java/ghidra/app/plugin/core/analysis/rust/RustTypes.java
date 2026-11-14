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

import ghidra.program.model.data.*;

/**
 * Builds the layout-stable core/alloc/std data types that rustc emits in compiled code: fat
 * pointers, {@code String}/{@code Vec}, {@code Rc}/{@code Arc} headers, vtables and
 * {@code core::panic::Location}. All types are placed in {@link RustConstants#RUST_CATEGORYPATH}.
 * <p>
 * The field order of {@code Vec}/{@code String} is not guaranteed by the language; the
 * {@code (cap, ptr, len)} order used here is the one produced by current rustc releases.
 */
public class RustTypes {

	public static final String STR = "&str";
	public static final String SLICE = "&[T]";
	public static final String TRAIT_OBJECT = "&dyn";
	public static final String VEC = "Vec";
	public static final String STRING = "String";
	public static final String RC_HEADER = "RcInner";
	public static final String ARC_HEADER = "ArcInner";
	public static final String VTABLE = "VTable";
	public static final String LOCATION = "Location";

	private RustTypes() {
		// utility
	}

	/**
	 * Creates (or replaces) all Rust core types in the given manager
	 *
	 * @param dtm the data type manager (a transaction must be open)
	 * @param pointerSize the target pointer size in bytes (4 or 8)
	 */
	public static void createAll(DataTypeManager dtm, int pointerSize) {
		str(dtm, pointerSize);
		slice(dtm, pointerSize);
		traitObject(dtm, pointerSize);
		vec(dtm, pointerSize);
		string(dtm, pointerSize);
		rcHeader(dtm, pointerSize, RC_HEADER);
		rcHeader(dtm, pointerSize, ARC_HEADER);
		vtable(dtm, pointerSize);
		location(dtm, pointerSize);
	}

	private static DataType usize(int pointerSize) {
		return pointerSize == 4 ? UnsignedIntegerDataType.dataType
				: UnsignedLongLongDataType.dataType;
	}

	private static DataType pointer(DataType target, int pointerSize) {
		return new PointerDataType(target, pointerSize);
	}

	private static StructureDataType struct(String name, DataTypeManager dtm) {
		return new StructureDataType(RustConstants.RUST_CATEGORYPATH, name, 0, dtm);
	}

	private static DataType commit(DataTypeManager dtm, StructureDataType st) {
		return dtm.resolve(st, DataTypeConflictHandler.REPLACE_HANDLER);
	}

	/** {@code &str}: data pointer and byte length */
	public static DataType str(DataTypeManager dtm, int ps) {
		StructureDataType st = struct(STR, dtm);
		st.add(pointer(CharDataType.dataType, ps), "ptr", "pointer to UTF-8 bytes, not terminated");
		st.add(usize(ps), "len", "length in bytes");
		return commit(dtm, st);
	}

	/** {@code &[T]}: data pointer and element count */
	public static DataType slice(DataTypeManager dtm, int ps) {
		StructureDataType st = struct(SLICE, dtm);
		st.add(pointer(VoidDataType.dataType, ps), "ptr", "pointer to the first element");
		st.add(usize(ps), "len", "element count");
		return commit(dtm, st);
	}

	/** {@code &dyn Trait} / {@code Box<dyn Trait>}: data pointer and vtable pointer */
	public static DataType traitObject(DataTypeManager dtm, int ps) {
		DataType vt = vtable(dtm, ps);
		StructureDataType st = struct(TRAIT_OBJECT, dtm);
		st.add(pointer(VoidDataType.dataType, ps), "data", "pointer to the concrete value");
		st.add(pointer(vt, ps), "vtable", "pointer to the trait vtable");
		return commit(dtm, st);
	}

	/** Vtable header: drop_in_place, size, align; trait methods follow */
	public static DataType vtable(DataTypeManager dtm, int ps) {
		StructureDataType st = struct(VTABLE, dtm);
		st.add(pointer(VoidDataType.dataType, ps), "drop_in_place", "may be null");
		st.add(usize(ps), "size", "size of the concrete type");
		st.add(usize(ps), "align", "alignment of the concrete type");
		return commit(dtm, st);
	}

	/** {@code Vec<T>}: capacity, buffer pointer, length */
	public static DataType vec(DataTypeManager dtm, int ps) {
		StructureDataType st = struct(VEC, dtm);
		st.add(usize(ps), "cap", "allocated capacity in elements");
		st.add(pointer(VoidDataType.dataType, ps), "ptr", "heap buffer");
		st.add(usize(ps), "len", "initialized elements");
		return commit(dtm, st);
	}

	/** {@code String}: a {@code Vec<u8>} */
	public static DataType string(DataTypeManager dtm, int ps) {
		StructureDataType st = struct(STRING, dtm);
		st.add(usize(ps), "cap", "allocated capacity in bytes");
		st.add(pointer(CharDataType.dataType, ps), "ptr", "heap buffer");
		st.add(usize(ps), "len", "length in bytes");
		return commit(dtm, st);
	}

	/** Header of the heap block behind {@code Rc<T>} / {@code Arc<T>}; the value follows */
	public static DataType rcHeader(DataTypeManager dtm, int ps, String name) {
		StructureDataType st = struct(name, dtm);
		st.add(usize(ps), "strong", "strong reference count");
		st.add(usize(ps), "weak", "weak reference count plus one");
		return commit(dtm, st);
	}

	/** {@code core::panic::Location}: file, line, column */
	public static DataType location(DataTypeManager dtm, int ps) {
		DataType strType = str(dtm, ps);
		StructureDataType st = struct(LOCATION, dtm);
		st.add(strType, "file", "source file path");
		st.add(UnsignedIntegerDataType.dataType, "line", "1-based line");
		st.add(UnsignedIntegerDataType.dataType, "col", "1-based column");
		return commit(dtm, st);
	}
}
