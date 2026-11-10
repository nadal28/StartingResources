/* Exact-build adapter for the game's own FResourceLayout generation.
 * No save loader, resource object or disk executable is patched. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include "game_build.h"

typedef struct { void *data; int num, max; } Array;
typedef struct { unsigned char *site; LONG64 original, replacement; } Patch;
typedef uintptr_t (*GenerateFn)(void *);
static HMODULE own_module;
static unsigned char *base, *allocation;
static Patch patches[2];
static unsigned installed;
static GenerateFn original_generate;
static wchar_t directory[MAX_PATH], report_path[MAX_PATH];
static int armed, active, supported, selected[2], selected_count, touched;
static unsigned selected_mask;
static unsigned char *instance;
static Array original_layouts, temporary_layout, temporary_layouts;

static void report(const char *state) {
    FILE *f=_wfopen(report_path,L"w");
    if (!f) return;
    fprintf(f,"%s\nversion=0.1.1\nsupported=%d\ninstalled=%u\narmed=%d\nmask=%u\nregions=%d\n",
            state,supported,installed,armed,selected_mask,touched);
    fclose(f);
}
static int readable(const void *p,size_t length) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_NOACCESS|PAGE_GUARD)) && (uintptr_t)p+length>=(uintptr_t)p &&
        (uintptr_t)p+length<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static int hash_matches(const wchar_t *path) {
    static const unsigned char expected[32]=EXPECTED_SHA256_BYTES;
    BCRYPT_ALG_HANDLE alg=NULL; BCRYPT_HASH_HANDLE hash=NULL;
    HANDLE f=INVALID_HANDLE_VALUE;
    unsigned char digest[32],*object=NULL,*buffer=NULL;
    DWORD object_size=0,received=0,size=0; int ok=0;
    if (BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,NULL,0)<0) goto done;
    if (BCryptGetProperty(alg,BCRYPT_OBJECT_LENGTH,(PUCHAR)&object_size,4,&received,0)<0) goto done;
    object=HeapAlloc(GetProcessHeap(),0,object_size);
    buffer=HeapAlloc(GetProcessHeap(),0,1024*1024);
    if (!object||!buffer||BCryptCreateHash(alg,&hash,object,object_size,NULL,0,0)<0) goto done;
    f=CreateFileW(path,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
    if (f==INVALID_HANDLE_VALUE) goto done;
    for (;;) {
        if (!ReadFile(f,buffer,1024*1024,&size,NULL)) goto done;
        if (!size) break;
        if (BCryptHashData(hash,buffer,size,0)<0) goto done;
    }
    if (BCryptFinishHash(hash,digest,32,0)<0) goto done;
    ok=memcmp(digest,expected,32)==0;
done:
    if (f!=INVALID_HANDLE_VALUE) CloseHandle(f);
    if (hash) BCryptDestroyHash(hash);
    if (alg) BCryptCloseAlgorithmProvider(alg,0);
    if (object) HeapFree(GetProcessHeap(),0,object);
    if (buffer) HeapFree(GetProcessHeap(),0,buffer);
    return ok;
}
static int supported_build(void) {
    wchar_t path[MAX_PATH];
    if (!GetModuleFileNameW(NULL,path,MAX_PATH)) return 0;
    const wchar_t *name=wcsrchr(path,L'\\'); name=name?name+1:path;
    if (_wcsicmp(name,L"ManorLords-Win64-Shipping.exe")) return 0;
    base=(unsigned char*)GetModuleHandleW(NULL);
    IMAGE_DOS_HEADER *dos=(IMAGE_DOS_HEADER*)base;
    if (dos->e_magic!=IMAGE_DOS_SIGNATURE||dos->e_lfanew<=0||dos->e_lfanew>4096) return 0;
    IMAGE_NT_HEADERS64 *nt=(IMAGE_NT_HEADERS64*)(base+dos->e_lfanew);
    return nt->Signature==IMAGE_NT_SIGNATURE && nt->FileHeader.Machine==IMAGE_FILE_MACHINE_AMD64 &&
        nt->FileHeader.TimeDateStamp==EXPECTED_TIMESTAMP && nt->OptionalHeader.SizeOfImage==EXPECTED_IMAGE_SIZE &&
        hash_matches(path);
}
static int main_region(unsigned char *region) {
    if (!readable(region,REGION_OWNER_OFFSET+8)) return 0;
    unsigned char *owner=*(unsigned char**)(region+REGION_OWNER_OFFSET);
    return readable(owner,PAWN_MAIN_OFFSET+1) && owner[PAWN_MAIN_OFFSET]==1;
}
/* Called at the start of EACH region, before the native layout is copied.
 * Other regions see their original layouts, including any supplied by scenarios. */
static void on_region(unsigned char *region) {
    if (!active) return;
    Array *layouts=(Array*)(instance+INSTANCE_LAYOUTS_OFFSET);
    if (main_region(region)) { *layouts=temporary_layouts; ++touched; }
    else *layouts=original_layouts;
}
static uintptr_t generate(void *engine) {
    int use=armed && supported && readable(instance,INSTANCE_LAYOUTS_OFFSET+sizeof(Array));
    if (!use) return original_generate(engine);
    original_layouts=*(Array*)(instance+INSTANCE_LAYOUTS_OFFSET);
    if (original_layouts.num<0||original_layouts.num>64) {
        armed=0; report("ERROR unexpected original layout array; unchanged");
        return original_generate(engine);
    }
    temporary_layout=(Array){selected,selected_count,selected_count};
    temporary_layouts=(Array){&temporary_layout,1,1};
    *(Array*)(instance+INSTANCE_LAYOUTS_OFFSET)=temporary_layouts;
    active=1; touched=0;
    uintptr_t result=original_generate(engine);
    *(Array*)(instance+INSTANCE_LAYOUTS_OFFSET)=original_layouts;
    active=0; armed=0;
    report(touched==1?"APPLIED native layout to starting region":"ERROR native layout scope was not exactly one region");
    return result;
}
static void absolute_jump(unsigned char *code,const void *destination) {
    memcpy(code,"\xff\x25\0\0\0\0",6); memcpy(code+6,&destination,8);
}
static unsigned char *allocate_near(uintptr_t address) {
    SYSTEM_INFO info;GetSystemInfo(&info);
    uintptr_t step=info.dwAllocationGranularity,start=address&~(step-1);
    for(uintptr_t distance=step;distance<0x7ffe0000u;distance+=step) {
        uintptr_t candidates[2]={start+distance,start>distance?start-distance:0};
        for(int i=0;i<2;++i) {
            uintptr_t p=candidates[i];
            if(p<(uintptr_t)info.lpMinimumApplicationAddress||p+4096>(uintptr_t)info.lpMaximumApplicationAddress)continue;
            unsigned char *block=VirtualAlloc((void*)p,4096,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
            if(block)return block;
        }
    }
    return NULL;
}
static int exchange(Patch *p,int restore) {
    DWORD previous,ignored;
    if (!VirtualProtect(p->site,8,PAGE_EXECUTE_READWRITE,&previous)) return 0;
    LONG64 want=restore?p->original:p->replacement,expected=restore?p->replacement:p->original;
    LONG64 was=InterlockedCompareExchange64((volatile LONG64*)p->site,want,expected);
    VirtualProtect(p->site,8,previous,&ignored);FlushInstructionCache(GetCurrentProcess(),p->site,8);
    return was==expected;
}
static int prepare(void) {
    for(int i=0;i<2;++i) if(memcmp(base+profiles[i].rva,profiles[i].bytes,profiles[i].size))return 0;
    allocation=allocate_near((uintptr_t)(base+profiles[0].rva));if(!allocation)return 0;
    /* Generator entry: replay eleven complete, position-independent instructions bytes. */
    memcpy(allocation,profiles[0].bytes,11);
    absolute_jump(allocation+11,base+profiles[0].rva+11);
    original_generate=(GenerateFn)allocation;
    absolute_jump(allocation+64,(void*)&generate);
    /* Region boundary: preserve flags, all volatile GPRs and XMM0..5 around a C callback.
     * The 0xc0-byte frame keeps this mid-function stack aligned and reserves ABI shadow space. */
    unsigned char *p=allocation+128;
    static const unsigned char save[]={0x9c,0x50,0x51,0x52,0x41,0x50,0x41,0x51,0x41,0x52,0x41,0x53,
        0x48,0x81,0xec,0x80,0,0,0};
    memcpy(p,save,sizeof(save));p+=sizeof(save);
    for(int i=0;i<6;++i) { unsigned char x[]={0xf3,0x0f,0x7f,(unsigned char)(0x44+i*8),0x24,(unsigned char)(0x20+i*16)};memcpy(p,x,6);p+=6; }
    memcpy(p,"\x48\x8b\x09\x48\xb8",5);p+=5;
    void *callback=(void*)&on_region;memcpy(p,&callback,8);p+=8;
    memcpy(p,"\xff\xd0",2);p+=2;
    for(int i=0;i<6;++i) { unsigned char x[]={0xf3,0x0f,0x6f,(unsigned char)(0x44+i*8),0x24,(unsigned char)(0x20+i*16)};memcpy(p,x,6);p+=6; }
    static const unsigned char restore[]={0x48,0x81,0xc4,0x80,0,0,0,0x41,0x5b,0x41,0x5a,0x41,0x59,0x41,0x58,0x5a,0x59,0x58,0x9d};
    memcpy(p,restore,sizeof(restore));p+=sizeof(restore);
    memcpy(p,profiles[1].bytes,11);p+=11;
    absolute_jump(p,base+profiles[1].rva+11);
    for(int i=0;i<2;++i) {
        Patch *q=&patches[i];q->site=base+profiles[i].rva;
        if((uintptr_t)q->site&7)return 0;
        unsigned char jump[8]={0xe9,0,0,0,0,0x90,0x90,0x90};
        intptr_t delta=(intptr_t)(allocation+(i?128:64))-(intptr_t)(q->site+5);
        if(delta<INT32_MIN||delta>INT32_MAX)return 0;
        int32_t displacement=(int32_t)delta;memcpy(jump+1,&displacement,4);
        memcpy(&q->original,q->site,8);memcpy(&q->replacement,jump,8);
    }
    DWORD previous;if(!VirtualProtect(allocation,4096,PAGE_EXECUTE_READ,&previous))return 0;
    FlushInstructionCache(GetCurrentProcess(),allocation,4096);
    for(int i=0;i<2;++i) {
        if(!exchange(&patches[i],0))return 0;
        installed|=1u<<i;
    }
    return 1;
}
__declspec(dllexport) int SR_Init(void *lua) {
    (void)lua;
    if(!directory[0]) {
        if(!GetModuleFileNameW(own_module,directory,MAX_PATH))return 0;
        wchar_t *end=wcsrchr(directory,L'\\');if(!end)return 0;*end=0;
        end=wcsrchr(directory,L'\\');if(!end)return 0;*end=0;
        _snwprintf(report_path,MAX_PATH,L"%ls\\native-status.txt",directory);
    }
    if(installed==3){report("READY");return 0;}
    if(installed){report("ERROR partial installation; restart required");return 0;}
    if(!supported_build()){report("UNSUPPORTED executable; no changes");return 0;}
    HMODULE pinned;
    if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN|GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
                           (LPCWSTR)(uintptr_t)&SR_Init,&pinned)){report("ERROR cannot retain adapter");return 0;}
    supported=prepare();
    if(!supported)for(int i=1;i>=0;--i)if((installed&(1u<<i))&&exchange(&patches[i],1))installed&=~(1u<<i);
    report(supported?"READY":"ERROR native code differs or installation failed");return 0;
}
__declspec(dllexport) int SR_Arm(void *lua) {
    (void)lua;armed=0;touched=0;
    wchar_t path[MAX_PATH];_snwprintf(path,MAX_PATH,L"%ls\\selection.txt",directory);
    FILE *f=_wfopen(path,L"r");if(!f){report("DISARMED missing selection");return 0;}
    char magic[8];unsigned mask;unsigned long long address;
    int count=fscanf(f,"%7s %u %llx",magic,&mask,&address);fclose(f);
    if(count!=3||strcmp(magic,"SR1")||!supported||installed!=3){report("DISARMED invalid selection");return 0;}
    unsigned allowed=(1u<<1)|(1u<<2)|(1u<<3)|(1u<<5)|(1u<<6)|(1u<<7)|(1u<<9)|(1u<<10)|(1u<<12);
    selected_count=0;selected_mask=mask;instance=(unsigned char*)(uintptr_t)address;
    for(int i=1;i<=12;++i)if(mask&(1u<<i)){if(selected_count==2){report("DISARMED more than two choices");return 0;}selected[selected_count++]=i;}
    if(!mask||(mask&~allowed)||!readable(instance,INSTANCE_LAYOUTS_OFFSET+16)){report("DISARMED invalid choices");return 0;}
    armed=1;report("ARMED for next new-game generation");return 0;
}
__declspec(dllexport) int SR_Disarm(void *lua) { (void)lua;armed=0;report("DISARMED");return 0; }
__declspec(dllexport) int SR_Stop(void *lua) {
    (void)lua;armed=0;supported=0;
    for(int i=1;i>=0;--i)if((installed&(1u<<i))&&exchange(&patches[i],1))installed&=~(1u<<i);
    report(installed?"STOPPED disabled; external code change detected":"STOPPED original code restored");return 0;
}
BOOL WINAPI DllMain(HINSTANCE module,DWORD reason,LPVOID reserved) {
    (void)reserved;if(reason==DLL_PROCESS_ATTACH){own_module=module;DisableThreadLibraryCalls(module);}return TRUE;
}
