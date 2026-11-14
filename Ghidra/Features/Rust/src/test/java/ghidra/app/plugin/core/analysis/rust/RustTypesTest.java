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

import ghidra.program.model.data.*;

public class RustTypesTest extends ghidra.test.AbstractGhidraHeadlessIntegrationTest {

	private static DataType get(DataTypeManager dtm, String name) {
		return dtm.getDataType(RustConstants.RUST_CATEGORYPATH, name);
	}

	@Test
	public void testSizes64() {
		DataTypeManager dtm = new StandAloneDataTypeManager("t");
		int tx = dtm.startTransaction("t");
		try {
			RustTypes.createAll(dtm, 8);
			assertEquals(16, get(dtm, RustTypes.STR).getLength());
			assertEquals(16, get(dtm, RustTypes.SLICE).getLength());
			assertEquals(16, get(dtm, RustTypes.TRAIT_OBJECT).getLength());
			assertEquals(24, get(dtm, RustTypes.VEC).getLength());
			assertEquals(24, get(dtm, RustTypes.STRING).getLength());
			assertEquals(16, get(dtm, RustTypes.RC_HEADER).getLength());
			assertEquals(16, get(dtm, RustTypes.ARC_HEADER).getLength());
			assertEquals(24, get(dtm, RustTypes.VTABLE).getLength());
			assertEquals(24, get(dtm, RustTypes.LOCATION).getLength());
		}
		finally {
			dtm.endTransaction(tx, true);
			dtm.close();
		}
	}

	@Test
	public void testSizes32() {
		DataTypeManager dtm = new StandAloneDataTypeManager("t");
		int tx = dtm.startTransaction("t");
		try {
			RustTypes.createAll(dtm, 4);
			assertEquals(8, get(dtm, RustTypes.STR).getLength());
			assertEquals(12, get(dtm, RustTypes.VEC).getLength());
			assertEquals(16, get(dtm, RustTypes.LOCATION).getLength());
		}
		finally {
			dtm.endTransaction(tx, true);
			dtm.close();
		}
	}

	@Test
	public void testFieldOrderAndIdempotence() {
		DataTypeManager dtm = new StandAloneDataTypeManager("t");
		int tx = dtm.startTransaction("t");
		try {
			RustTypes.createAll(dtm, 8);
			RustTypes.createAll(dtm, 8);
			Structure vec = (Structure) get(dtm, RustTypes.VEC);
			assertEquals("cap", vec.getComponent(0).getFieldName());
			assertEquals("ptr", vec.getComponent(1).getFieldName());
			assertEquals("len", vec.getComponent(2).getFieldName());
			Structure loc = (Structure) get(dtm, RustTypes.LOCATION);
			assertEquals("file", loc.getComponent(0).getFieldName());
			assertEquals(RustTypes.STR, loc.getComponent(0).getDataType().getName());
		}
		finally {
			dtm.endTransaction(tx, true);
			dtm.close();
		}
	}
}
