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

import org.junit.*;

import ghidra.app.util.importer.MessageLog;
import ghidra.program.database.ProgramBuilder;
import ghidra.program.model.address.Address;
import ghidra.program.model.data.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import ghidra.test.AbstractGhidraHeadlessIntegrationTest;
import ghidra.util.task.TaskMonitor;

public class RustPanicAnalyzerTest extends AbstractGhidraHeadlessIntegrationTest {

	private ProgramBuilder builder;
	private Program program;
	private int tx;

	@Before
	public void setUp() throws Exception {
		builder = new ProgramBuilder("rust-panic", ProgramBuilder._X64);
		builder.createMemory(".text", "0x401000", 0x100);
		builder.createMemory(".rodata", "0x402000", 0x400);
		program = builder.getProgram();
		tx = program.startTransaction("test");
	}

	@After
	public void tearDown() {
		program.endTransaction(tx, true);
		builder.dispose();
	}

	private Function function(String ns, String name, String addr) throws Exception {
		Namespace space = program.getSymbolTable()
				.getOrCreateNameSpace(program.getGlobalNamespace(), ns, SourceType.ANALYSIS);
		Function f = builder.createEmptyFunction(name, addr, 8, DataType.DEFAULT);
		f.setParentNamespace(space);
		return f;
	}

	@Test
	public void testPanicFunctionsMarkedNoReturn() throws Exception {
		Function panic = function("core::panicking", "panic", "0x401000");
		Function other = function("core", "mem_swap", "0x401010");
		assertEquals(1, RustPanicAnalyzer.markNoReturn(program, TaskMonitor.DUMMY));
		assertTrue(panic.hasNoReturn());
		assertFalse(other.hasNoReturn());
	}

	@Test
	public void testNestedNamespacePanicFunction() throws Exception {
		Namespace core = program.getSymbolTable()
				.getOrCreateNameSpace(program.getGlobalNamespace(), "core", SourceType.ANALYSIS);
		Namespace panicking =
			program.getSymbolTable().getOrCreateNameSpace(core, "panicking", SourceType.ANALYSIS);
		Function f = builder.createEmptyFunction("panic_fmt", "0x401020", 8, DataType.DEFAULT);
		f.setParentNamespace(panicking);
		assertEquals(1, RustPanicAnalyzer.markNoReturn(program, TaskMonitor.DUMMY));
		assertTrue(f.hasNoReturn());
	}

	@Test
	public void testLocationRecognised() throws Exception {
		String path = "src/main.rs";
		builder.setBytes("0x402000", path.getBytes());
		// Location at 0x402040: ptr, len, line, col
		builder.setBytes("0x402040", "00 20 40 00 00 00 00 00 " + "0b 00 00 00 00 00 00 00 " +
			"2a 00 00 00 " + "05 00 00 00");
		// a decoy with a pointer to non-.rs bytes
		builder.setBytes("0x402080", "40 20 40 00 00 00 00 00 " + "04 00 00 00 00 00 00 00 " +
			"01 00 00 00 " + "01 00 00 00");

		assertEquals(1, RustPanicAnalyzer.labelLocations(program, TaskMonitor.DUMMY,
			new MessageLog()));

		Address at = builder.addr("0x402040");
		Data d = program.getListing().getDefinedDataAt(at);
		assertNotNull(d);
		assertEquals(RustTypes.LOCATION, d.getDataType().getName());
		Symbol s = program.getSymbolTable().getPrimarySymbol(at);
		assertEquals("panic_loc_main_rs_42_5", s.getName());
		assertEquals("src/main.rs:42:5", program.getListing().getComment(CommentType.EOL, at));
		assertNull(program.getListing().getDefinedDataAt(builder.addr("0x402080")));
	}

	@Test
	public void testLabelName() {
		assertEquals("panic_loc_lib_rs_7_9", RustPanicAnalyzer.labelName("src/lib.rs", 7, 9));
		assertEquals("panic_loc_a_b_rs_1_1", RustPanicAnalyzer.labelName("C:\\x\\a-b.rs", 1, 1));
	}
}
