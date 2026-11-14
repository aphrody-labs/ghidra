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

import java.nio.charset.StandardCharsets;

import ghidra.app.services.*;
import ghidra.app.util.importer.MessageLog;
import ghidra.app.util.sourcelanguage.RustSourceLanguage;
import ghidra.framework.options.Options;
import ghidra.program.model.address.*;
import ghidra.program.model.data.DataType;
import ghidra.program.model.data.DataUtilities;
import ghidra.program.model.data.DataUtilities.ClearDataMode;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryAccessException;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.SourceType;
import ghidra.util.exception.CancelledException;
import ghidra.util.task.TaskMonitor;

/**
 * Marks the panic entry points of core/alloc/std as non-returning, and recognises
 * {@code core::panic::Location} structures (file, line, column) in initialized memory, creating
 * and labelling them.
 */
public class RustPanicAnalyzer extends AbstractAnalyzer {

	private static final String NAME = "Rust Panic Analyzer";
	private static final String DESCRIPTION =
		"Sets noreturn on Rust panic functions and labels panic Location structures";

	static final int MAX_LOCATIONS = 100_000;
	private static final long MAX_LINE = 10_000_000L;
	private static final long MAX_COL = 10_000L;
	private static final int MAX_PATH = 4096;

	public RustPanicAnalyzer() {
		super(NAME, DESCRIPTION, AnalyzerType.BYTE_ANALYZER);
		setPriority(AnalysisPriority.LOW_PRIORITY);
		setDefaultEnablement(true);
		setSupportsOneTimeAnalysis(true);
	}

	@Override
	public boolean canAnalyze(Program program) {
		return program.getSourceLanguageIDs().contains(RustSourceLanguage.RUST_ID);
	}

	@Override
	public boolean added(Program program, AddressSetView set, TaskMonitor monitor, MessageLog log)
			throws CancelledException {
		markNoReturn(program, monitor);
		labelLocations(program, monitor, log);
		return true;
	}

	@Override
	public void registerOptions(Options options, Program program) {
		// No options
	}

	@Override
	public void optionsChanged(Options options, Program program) {
		// No options
	}

	/**
	 * Sets noreturn on every function whose qualified name is a known panic entry point
	 *
	 * @param program the program
	 * @param monitor the monitor
	 * @return the number of functions changed
	 * @throws CancelledException if cancelled
	 */
	static int markNoReturn(Program program, TaskMonitor monitor) throws CancelledException {
		int count = 0;
		for (Function f : program.getFunctionManager().getFunctions(true)) {
			monitor.checkCancelled();
			if (!f.hasNoReturn() && RustPanicFunctions.isPanicFunction(f.getName(true))) {
				f.setNoReturn(true);
				count++;
			}
		}
		return count;
	}

	/**
	 * Finds and labels {@code Location} structures: an {@code &str} whose bytes name a
	 * {@code .rs} file, followed by a plausible 32-bit line and column
	 *
	 * @param program the program
	 * @param monitor the monitor
	 * @param log the log
	 * @return the number of locations created
	 * @throws CancelledException if cancelled
	 */
	static int labelLocations(Program program, TaskMonitor monitor, MessageLog log)
			throws CancelledException {
		int ps = program.getDefaultPointerSize();
		if (ps != 4 && ps != 8) {
			return 0;
		}
		Memory memory = program.getMemory();
		DataType location = RustTypes.location(program.getDataTypeManager(), ps);
		int count = 0;
		for (MemoryBlock block : memory.getBlocks()) {
			if (!block.isInitialized() || block.isExecute() || block.isVolatile()) {
				continue;
			}
			Address a = block.getStart();
			long span = block.getSize() - location.getLength();
			if (span < 0) {
				continue;
			}
			long steps = span / ps;
			for (long i = 0; i <= steps && count < MAX_LOCATIONS; i++) {
				if ((i & 0xffff) == 0) {
					monitor.checkCancelled();
				}
				Address at = a.add(i * ps);
				if (tryLabel(program, memory, at, ps, location)) {
					count++;
					i += location.getLength() / ps - 1;
				}
			}
		}
		return count;
	}

	private static boolean tryLabel(Program program, Memory memory, Address at, int ps,
			DataType location) {
		try {
			long line = memory.getInt(at.add(2L * ps)) & 0xffffffffL;
			long col = memory.getInt(at.add(2L * ps + 4)) & 0xffffffffL;
			if (line < 1 || line > MAX_LINE || col < 1 || col > MAX_COL) {
				return false;
			}
			long len = ps == 8 ? memory.getLong(at.add(ps)) : memory.getInt(at.add(ps)) & 0xffffffffL;
			if (len < 4 || len > MAX_PATH) {
				return false;
			}
			long ptr = ps == 8 ? memory.getLong(at) : memory.getInt(at) & 0xffffffffL;
			Address file = program.getAddressFactory().getDefaultAddressSpace().getAddress(ptr);
			if (file == null || !memory.contains(file) || !memory.contains(file.add(len - 1))) {
				return false;
			}
			byte[] bytes = new byte[(int) len];
			if (memory.getBytes(file, bytes) != bytes.length) {
				return false;
			}
			String path = new String(bytes, StandardCharsets.ISO_8859_1);
			if (!path.endsWith(".rs") || !isPrintable(path)) {
				return false;
			}
			if (program.getListing().getDefinedDataAt(at) != null &&
				program.getListing().getDefinedDataAt(at).getDataType().isEquivalent(location)) {
				return true;
			}
			Data d = DataUtilities.createData(program, at, location, -1,
				ClearDataMode.CLEAR_ALL_UNDEFINED_CONFLICT_DATA);
			program.getReferenceManager()
					.addMemoryReference(at, file,
						ghidra.program.model.symbol.RefType.DATA, SourceType.ANALYSIS, 0);
			program.getSymbolTable()
					.createLabel(at, labelName(path, line, col), SourceType.ANALYSIS);
			program.getListing().setComment(at, CommentType.EOL, path + ":" + line + ":" + col);
			return d != null;
		}
		catch (MemoryAccessException | AddressOutOfBoundsException | IllegalArgumentException
				| ghidra.util.exception.InvalidInputException
				| ghidra.program.model.util.CodeUnitInsertionException e) {
			return false;
		}
	}

	private static boolean isPrintable(String s) {
		for (int i = 0; i < s.length(); i++) {
			char c = s.charAt(i);
			if (c < 0x20 || c > 0x7e) {
				return false;
			}
		}
		return true;
	}

	/**
	 * Builds the label for a location: {@code panic_loc_<file>_<line>_<col>} with every
	 * character that is not a letter or digit replaced by an underscore
	 *
	 * @param path the source path
	 * @param line the line
	 * @param col the column
	 * @return the label
	 */
	public static String labelName(String path, long line, long col) {
		String base = path.substring(path.lastIndexOf('/') + 1);
		base = base.substring(base.lastIndexOf('\\') + 1).replaceAll("[^A-Za-z0-9]", "_");
		return "panic_loc_" + base + "_" + line + "_" + col;
	}
}
