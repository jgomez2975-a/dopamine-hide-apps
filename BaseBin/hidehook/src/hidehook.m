#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <objc/runtime.h>
#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <netinet/in.h>
#include <spawn.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <unistd.h>

#define ORIG(fn, type) ((type)dlsym(RTLD_NEXT, #fn))
#define DYLD_INTERPOSE(_new,_orig) \
	__attribute__((used)) static struct { const void *n; const void *o; } _interpose_##_orig \
	__attribute__((section("__DATA,__interpose"))) = { (const void *)(unsigned long)&_new, (const void *)(unsigned long)&_orig }

static bool str_eq(const char *a, const char *b) { return a && b && strcmp(a, b) == 0; }

static bool str_has_prefix(const char *s, const char *p)
{
	if (!s || !p) return false;
	size_t n = strlen(p);
	return strncmp(s, p, n) == 0;
}

static bool str_contains(const char *s, const char *n)
{
	return s && n && strstr(s, n) != NULL;
}

static const char *gHiddenExact[] = {
	"/var/jb", "/private/var/jb", "/var/binpack", "/private/var/binpack",
	"/var/LIY", "/var/lib", "/var/lib/dpkg", "/var/lib/apt", "/var/cache/apt",
	"/var/log/apt", "/var/mobile/Library/Cydia", "/var/mobile/Library/Sileo",
	"/var/mobile/Library/Application Support/xyz.willy.Zebra",
	"/var/mobile/Library/Preferences/com.opa334.Dopamine.plist",
	"/usr/lib/systemhook.dylib", "/usr/lib/hidehook.dylib",
	"/usr/lib/TweakLoader.dylib", "/usr/lib/TweakInject.dylib",
	"/usr/lib/substitute-inserter.dylib", "/usr/lib/substitute-loader.dylib",
	"/usr/lib/libsubstitute.dylib", "/usr/lib/libhooker.dylib",
	"/usr/lib/libellekit.dylib", "/usr/lib/ellekit.dylib",
	"/usr/lib/CydiaSubstrate.framework", "/usr/lib/libsubstrate.dylib",
	"/usr/lib/substrate", "/usr/sbin/sshd", "/usr/bin/ssh", "/usr/bin/scp",
	"/usr/bin/dpkg", "/usr/bin/apt", "/usr/bin/apt-get", "/usr/bin/uicache",
	"/usr/bin/ldid", "/bin/bash", "/bin/sh", "/bin/zsh", "/etc/apt", "/etc/ssh",
	"/Library/MobileSubstrate", "/Library/TweakInject",
	"/Library/Frameworks/CydiaSubstrate.framework",
	"/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
	"/Applications/Filza.app", "/Applications/TrollStore.app",
	"/Applications/Dopamine.app", "/Applications/Undecimus.app",
	"/Applications/palera1n.app", "/.bootstrapped_electra",
	"/usr/libexec/sftp-server", "/usr/libexec/sshd-keygen-wrapper",
	"/usr/libexec/cydia", NULL
};

static const char *gHiddenNeedles[] = {
	"/var/jb", "/private/var/jb", "/procursus", "/basebin", "Cydia", "cydia",
	"Sileo", "sileo", "Zebra.app", "Filza", "TrollStore", "Dopamine", "ellekit",
	"libhooker", "MobileSubstrate", "TweakLoader", "TweakInject",
	"systemhook.dylib", "hidehook.dylib", "substitute", "SubstrateLoader",
	"frida", "FridaGadget", "libfrida", "cycript", "sslkill", "SSLKillSwitch",
	"Choicy", "shadow.dylib", "vnodebypass", "libjailbreak", "palera1n",
	"unc0ver", "checkra1n", "odyssey", "taurine", "xina", "/.installed_",
	NULL
};

static const char *gHiddenDirents[] = {
	"systemhook.dylib", "hidehook.dylib", "TweakLoader.dylib", "TweakInject.dylib",
	"libsubstrate.dylib", "libhooker.dylib", "ellekit.dylib", "libellekit.dylib",
	"substitute-inserter.dylib", "CydiaSubstrate.framework", "substrate", NULL
};

static const char *gHiddenSchemes[] = {
	"cydia", "sileo", "zbra", "filza", "undecimus", "activator", "trollstore",
	"apple-magnifier", "santander", "icleaner", "dopamine", "palera1n",
	"checkra1n", "altstore", "sidestore", NULL
};

static bool is_hidden_path(const char *path)
{
	if (!path || path[0] == '\0') return false;
	char tmp[PATH_MAX];
	const char *p = path;
	if (str_has_prefix(path, "/private/var/")) {
		snprintf(tmp, sizeof(tmp), "/var/%s", path + strlen("/private/var/"));
		p = tmp;
	} else if (str_has_prefix(path, "/private/etc/")) {
		snprintf(tmp, sizeof(tmp), "/etc/%s", path + strlen("/private/etc/"));
		p = tmp;
	}
	for (size_t i = 0; gHiddenExact[i]; i++) {
		if (str_eq(path, gHiddenExact[i]) || str_eq(p, gHiddenExact[i])) return true;
	}
	for (size_t i = 0; gHiddenNeedles[i]; i++) {
		if (str_contains(path, gHiddenNeedles[i]) || str_contains(p, gHiddenNeedles[i])) return true;
	}
	return false;
}

static bool is_hidden_dirent(const char *name)
{
	if (!name) return false;
	for (size_t i = 0; gHiddenDirents[i]; i++) {
		if (str_eq(name, gHiddenDirents[i])) return true;
	}
	return is_hidden_path(name);
}

static int deny_errno(void) { errno = ENOENT; return -1; }

int hide_access(const char *path, int mode)
{
	if (is_hidden_path(path)) return deny_errno();
	return ORIG(access, int (*)(const char *, int))(path, mode);
}

int hide_faccessat(int fd, const char *path, int mode, int flags)
{
	if (is_hidden_path(path)) return deny_errno();
	return ORIG(faccessat, int (*)(int, const char *, int, int))(fd, path, mode, flags);
}

int hide_stat(const char *path, struct stat *buf)
{
	if (is_hidden_path(path)) return deny_errno();
	return ORIG(stat, int (*)(const char *, struct stat *))(path, buf);
}

int hide_lstat(const char *path, struct stat *buf)
{
	if (is_hidden_path(path)) return deny_errno();
	return ORIG(lstat, int (*)(const char *, struct stat *))(path, buf);
}

int hide_fstatat(int fd, const char *path, struct stat *buf, int flag)
{
	if (is_hidden_path(path)) return deny_errno();
	return ORIG(fstatat, int (*)(int, const char *, struct stat *, int))(fd, path, buf, flag);
}

int hide_statfs(const char *path, struct statfs *buf)
{
	if (is_hidden_path(path)) return deny_errno();
	int r = ORIG(statfs, int (*)(const char *, struct statfs *))(path, buf);
	if (r == 0 && buf && path && (str_eq(path, "/usr/lib") || str_has_prefix(path, "/usr/lib"))) {
		if (str_contains(buf->f_mntfromname, "bindfs") || str_contains(buf->f_mntfromname, "fakelib") || str_contains(buf->f_mntfromname, "/var/jb")) {
			strlcpy(buf->f_mntonname, "/usr", sizeof(buf->f_mntonname));
			strlcpy(buf->f_mntfromname, "/dev/disk0s1s1", sizeof(buf->f_mntfromname));
			strlcpy(buf->f_fstypename, "apfs", sizeof(buf->f_fstypename));
		}
	}
	return r;
}

int hide_open(const char *path, int flags, ...)
{
	if (is_hidden_path(path)) return deny_errno();
	if (flags & O_CREAT) {
		va_list ap; va_start(ap, flags); mode_t mode = (mode_t)va_arg(ap, int); va_end(ap);
		return ORIG(open, int (*)(const char *, int, ...))(path, flags, mode);
	}
	return ORIG(open, int (*)(const char *, int, ...))(path, flags);
}

int hide_openat(int fd, const char *path, int flags, ...)
{
	if (is_hidden_path(path)) return deny_errno();
	if (flags & O_CREAT) {
		va_list ap; va_start(ap, flags); mode_t mode = (mode_t)va_arg(ap, int); va_end(ap);
		return ORIG(openat, int (*)(int, const char *, int, ...))(fd, path, flags, mode);
	}
	return ORIG(openat, int (*)(int, const char *, int, ...))(fd, path, flags);
}

FILE *hide_fopen(const char *path, const char *mode)
{
	if (is_hidden_path(path)) { errno = ENOENT; return NULL; }
	return ORIG(fopen, FILE *(*)(const char *, const char *))(path, mode);
}

DIR *hide_opendir(const char *path)
{
	if (is_hidden_path(path)) { errno = ENOENT; return NULL; }
	return ORIG(opendir, DIR *(*)(const char *))(path);
}

struct dirent *hide_readdir(DIR *dir)
{
	struct dirent *(*orig)(DIR *) = ORIG(readdir, struct dirent *(*)(DIR *));
	struct dirent *ent;
	while ((ent = orig(dir))) {
		if (!is_hidden_dirent(ent->d_name)) return ent;
	}
	return NULL;
}

char *hide_realpath(const char *path, char *resolved)
{
	if (is_hidden_path(path)) { errno = ENOENT; return NULL; }
	char *r = ORIG(realpath, char *(*)(const char *, char *))(path, resolved);
	if (r && is_hidden_path(r)) { errno = ENOENT; return NULL; }
	return r;
}

ssize_t hide_readlink(const char *path, char *buf, size_t bufsiz)
{
	if (is_hidden_path(path)) return deny_errno();
	return ORIG(readlink, ssize_t (*)(const char *, char *, size_t))(path, buf, bufsiz);
}

int hide_getattrlist(const char *path, void *attrList, void *attrBuf, size_t attrBufSize, unsigned int options)
{
	if (is_hidden_path(path)) return deny_errno();
	return ORIG(getattrlist, int (*)(const char *, void *, void *, size_t, unsigned int))(path, attrList, attrBuf, attrBufSize, options);
}

char *hide_getenv(const char *name)
{
	if (name && (str_eq(name, "DYLD_INSERT_LIBRARIES") || str_eq(name, "DYLD_LIBRARY_PATH") ||
		str_eq(name, "_MSSafeMode") || str_eq(name, "_SafeMode") || str_eq(name, "JB_ROOT_PATH"))) {
		return NULL;
	}
	return ORIG(getenv, char *(*)(const char *))(name);
}

int hide_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen)
{
	if (name && (str_contains(name, "bootargs") || str_contains(name, "amfi"))) {
		if (oldp && oldlenp && *oldlenp) { memset(oldp, 0, *oldlenp); *oldlenp = 0; }
		errno = ENOENT;
		return -1;
	}
	return ORIG(sysctlbyname, int (*)(const char *, void *, size_t *, void *, size_t))(name, oldp, oldlenp, newp, newlen);
}

pid_t hide_fork(void)
{
	errno = ENOSYS;
	return -1;
}

void *hide_dlopen(const char *path, int mode)
{
	if (is_hidden_path(path)) { errno = ENOENT; return NULL; }
	return ORIG(dlopen, void *(*)(const char *, int))(path, mode);
}

int hide_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen)
{
	if (addr && addr->sa_family == AF_INET && addrlen >= sizeof(struct sockaddr_in)) {
		const struct sockaddr_in *in = (const struct sockaddr_in *)addr;
		uint16_t port = ntohs(in->sin_port);
		if (port == 22 || port == 44 || port == 2222 || port == 27042 || port == 27043 || port == 3141) {
			errno = ECONNREFUSED;
			return -1;
		}
	}
	return ORIG(connect, int (*)(int, const struct sockaddr *, socklen_t))(sockfd, addr, addrlen);
}

uint32_t hide_dyld_image_count(void)
{
	uint32_t (*orig)(void) = ORIG(_dyld_image_count, uint32_t (*)(void));
	const char *(*orig_name)(uint32_t) = ORIG(_dyld_get_image_name, const char *(*)(uint32_t));
	uint32_t count = orig();
	uint32_t vis = 0;
	for (uint32_t i = 0; i < count; i++) {
		const char *n = orig_name(i);
		if (!is_hidden_path(n)) vis++;
	}
	return vis;
}

const char *hide_dyld_get_image_name(uint32_t image_index)
{
	uint32_t (*orig_count)(void) = ORIG(_dyld_image_count, uint32_t (*)(void));
	const char *(*orig_name)(uint32_t) = ORIG(_dyld_get_image_name, const char *(*)(uint32_t));
	uint32_t count = orig_count();
	uint32_t vis = 0;
	for (uint32_t i = 0; i < count; i++) {
		const char *n = orig_name(i);
		if (is_hidden_path(n)) continue;
		if (vis == image_index) return n;
		vis++;
	}
	return NULL;
}

static BOOL (*orig_fileExists)(id, SEL, NSString *) = NULL;
static BOOL hook_fileExists(id self, SEL sel, NSString *path)
{
	if (path && is_hidden_path(path.fileSystemRepresentation)) return NO;
	return orig_fileExists(self, sel, path);
}

static BOOL (*orig_fileExistsDir)(id, SEL, NSString *, BOOL *) = NULL;
static BOOL hook_fileExistsDir(id self, SEL sel, NSString *path, BOOL *isDir)
{
	if (path && is_hidden_path(path.fileSystemRepresentation)) {
		if (isDir) *isDir = NO;
		return NO;
	}
	return orig_fileExistsDir(self, sel, path, isDir);
}

static NSArray *(*orig_contents)(id, SEL, NSString *, NSError **) = NULL;
static NSArray *hook_contents(id self, SEL sel, NSString *path, NSError **err)
{
	if (path && is_hidden_path(path.fileSystemRepresentation)) {
		if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:nil];
		return nil;
	}
	NSArray *items = orig_contents(self, sel, path, err);
	if (!items) return items;
	NSMutableArray *out = [NSMutableArray array];
	for (NSString *item in items) {
		if (!is_hidden_dirent(item.UTF8String) && !is_hidden_path(item.UTF8String)) [out addObject:item];
	}
	return out;
}

static BOOL (*orig_canOpenURL)(id, SEL, NSURL *) = NULL;
static BOOL hook_canOpenURL(id self, SEL sel, NSURL *url)
{
	NSString *scheme = url.scheme.lowercaseString;
	if (scheme) {
		for (size_t i = 0; gHiddenSchemes[i]; i++) {
			if ([scheme isEqualToString:@(gHiddenSchemes[i])]) return NO;
		}
	}
	if (url.path && is_hidden_path(url.path.fileSystemRepresentation)) return NO;
	return orig_canOpenURL(self, sel, url);
}

static void swizzle(Class cls, SEL sel, IMP neu, IMP *orig)
{
	Method m = class_getInstanceMethod(cls, sel);
	if (!m) return;
	*orig = method_setImplementation(m, neu);
}

__attribute__((constructor(101)))
static void hidehook_init(void)
{
	unsetenv("DYLD_INSERT_LIBRARIES");
	unsetenv("_MSSafeMode");
	unsetenv("_SafeMode");
	unsetenv("JB_ROOT_PATH");
	swizzle(NSFileManager.class, @selector(fileExistsAtPath:), (IMP)hook_fileExists, (IMP *)&orig_fileExists);
	swizzle(NSFileManager.class, @selector(fileExistsAtPath:isDirectory:), (IMP)hook_fileExistsDir, (IMP *)&orig_fileExistsDir);
	swizzle(NSFileManager.class, @selector(contentsOfDirectoryAtPath:error:), (IMP)hook_contents, (IMP *)&orig_contents);
	swizzle(UIApplication.class, @selector(canOpenURL:), (IMP)hook_canOpenURL, (IMP *)&orig_canOpenURL);
}

DYLD_INTERPOSE(hide_access, access);
DYLD_INTERPOSE(hide_faccessat, faccessat);
DYLD_INTERPOSE(hide_stat, stat);
DYLD_INTERPOSE(hide_lstat, lstat);
DYLD_INTERPOSE(hide_fstatat, fstatat);
DYLD_INTERPOSE(hide_statfs, statfs);
DYLD_INTERPOSE(hide_open, open);
DYLD_INTERPOSE(hide_openat, openat);
DYLD_INTERPOSE(hide_fopen, fopen);
DYLD_INTERPOSE(hide_opendir, opendir);
DYLD_INTERPOSE(hide_readdir, readdir);
DYLD_INTERPOSE(hide_realpath, realpath);
DYLD_INTERPOSE(hide_readlink, readlink);
DYLD_INTERPOSE(hide_getattrlist, getattrlist);
DYLD_INTERPOSE(hide_getenv, getenv);
DYLD_INTERPOSE(hide_sysctlbyname, sysctlbyname);
DYLD_INTERPOSE(hide_fork, fork);
DYLD_INTERPOSE(hide_dlopen, dlopen);
DYLD_INTERPOSE(hide_connect, connect);
DYLD_INTERPOSE(hide_dyld_image_count, _dyld_image_count);
DYLD_INTERPOSE(hide_dyld_get_image_name, _dyld_get_image_name);
