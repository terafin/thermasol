import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;
import java.io.*;
public class DecompAll extends GhidraScript {
  public void run() throws Exception {
    String out = getScriptArgs()[0];
    // create functions from vector table entries
    Memory m = currentProgram.getMemory();
    Address base = toAddr(0x08000000);
    for (int i=1;i<118;i++){ long v = m.getInt(base.add(i*4)) & 0xffffffffL; if (v>0x08000000L && v<0x08080000L) { Address a=toAddr(v & ~1L); if (getFunctionAt(a)==null){ disassemble(a); createFunction(a,null);} } }
    analyzeAll(currentProgram);
    DecompInterface d = new DecompInterface(); d.openProgram(currentProgram);
    PrintWriter pw = new PrintWriter(new FileWriter(out));
    int n=0;
    for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
      DecompileResults r = d.decompileFunction(f, 60, monitor);
      pw.println("// ==== " + f.getEntryPoint() + " " + f.getName());
      if (r.decompileCompleted()) pw.println(r.getDecompiledFunction().getC()); else pw.println("// FAILED");
      n++;
    }
    pw.close(); println("functions: "+n);
  }
}
