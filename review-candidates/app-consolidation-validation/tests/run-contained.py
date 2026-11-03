import ctypes,errno,subprocess,sys,pathlib
s=ctypes.CDLL('libseccomp.so.2',use_errno=True)
s.seccomp_init.argtypes=[ctypes.c_uint32];s.seccomp_init.restype=ctypes.c_void_p
s.seccomp_syscall_resolve_name.argtypes=[ctypes.c_char_p];s.seccomp_syscall_resolve_name.restype=ctypes.c_int
s.seccomp_rule_add.argtypes=[ctypes.c_void_p,ctypes.c_uint32,ctypes.c_int,ctypes.c_uint]
s.seccomp_load.argtypes=[ctypes.c_void_p]
def containment():
 c=s.seccomp_init(0x7fff0000)
 for name in [b'socket',b'connect',b'socketpair']:
  assert s.seccomp_rule_add(c,0x50000|errno.EPERM,s.seccomp_syscall_resolve_name(name),0)==0
 assert s.seccomp_load(c)==0
root=pathlib.Path(__file__).resolve().parent.parent
for test,log in [('Test-CandidateParse.ps1','parse.txt'),('Test-App-Review.ps1','fixtures.txt'),('Test-OperationalGuards.ps1','operational-guards.txt')]:
 r=subprocess.run([sys.argv[1],'-NoProfile','-NonInteractive','-File',str(root/'tests'/test)],preexec_fn=containment,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 (root/'validation'/log).write_text(r.stdout);print(r.stdout)
 if r.returncode:raise SystemExit(r.returncode)
