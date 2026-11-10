/* Extend a private copy of the native hunter job, preserving its AI, reserves,
 * work areas, carcass transport and crafting. Original instructions stay intact
 * except for one atomic entry detour. The copy has its own Windows unwind table.
 * Requires base, allocate_near() and absolute_jump() from the adapter. */
#include "deer_hunting_build.h"

typedef unsigned char (*HuntCraftFn)(void*,int,unsigned char,Array*,void*,unsigned char);
typedef int (*HuntStockFn)(void*,int);
static unsigned char *hunting_code;
static RUNTIME_FUNCTION hunting_functions[sizeof(hunting_ranges)/sizeof(hunting_ranges[0])];
static HuntCraftFn hunt_craft;
static HuntStockFn hunt_stock;

static unsigned char craft_wild_game(void *unit,int good,unsigned char flag,
                                    Array *out,void *camp,unsigned char final_flag) {
    if (camp && hunt_stock(camp,2)>0) good=331;
    return hunt_craft(unit,good,flag,out,camp,final_flag);
}
static int carcasses_in_camp(void *camp,int good) {
    return hunt_stock(camp,good)+hunt_stock(camp,2);
}
static int hunt_relative(unsigned char *field,const void *target,const void *next) {
    intptr_t delta=(intptr_t)target-(intptr_t)next;
    if(delta<INT32_MIN||delta>INT32_MAX)return 0;
    int32_t value=(int32_t)delta;memcpy(field,&value,4);return 1;
}
static int hunt_branch(unsigned char *site,const void *target) {
    site[0]=0xe9;return hunt_relative(site+1,target,site+5);
}
static int hunting_matches(void) {
    static const unsigned char expected[32]=HUNTING_SHA256_BYTES;
    BCRYPT_ALG_HANDLE alg=NULL;BCRYPT_HASH_HANDLE hash=NULL;
    unsigned char digest[32],*object=NULL;DWORD size=0,received=0;int ok=0;
    if(BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,NULL,0)<0)goto done;
    if(BCryptGetProperty(alg,BCRYPT_OBJECT_LENGTH,(PUCHAR)&size,4,&received,0)<0)goto done;
    object=HeapAlloc(GetProcessHeap(),0,size);
    if(!object||BCryptCreateHash(alg,&hash,object,size,NULL,0,0)<0)goto done;
    if(BCryptHashData(hash,base+HUNTING_RVA,HUNTING_SIZE,0)<0)goto done;
    if(BCryptFinishHash(hash,digest,32,0)<0)goto done;
    ok=memcmp(digest,expected,32)==0;
done:
    if(hash)BCryptDestroyHash(hash);
    if(alg)BCryptCloseAlgorithmProvider(alg,0);
    if(object)HeapFree(GetProcessHeap(),0,object);
    return ok;
}
static int prepare_hunting(void) {
    if(!hunting_matches())return 0;
    if(hunting_code)return 1;
    unsigned char *copy=allocate_near((uintptr_t)(base+HUNTING_RVA),8192);
    if(!copy)return 0;
    memcpy(copy,base+HUNTING_RVA,HUNTING_SIZE);
    for(size_t i=0;i<sizeof(hunting_fixups)/sizeof(hunting_fixups[0]);++i) {
        const HuntFixup *fix=&hunting_fixups[i];
        if(!hunt_relative(copy+fix->offset,base+fix->target,copy+fix->next))return 0;
    }
    hunt_craft=(HuntCraftFn)(base+0x4e13e60);
    hunt_stock=(HuntStockFn)(base+0x4d13cc0);
    unsigned char *craft_relay=copy+4096,*stock_relay=copy+4128;
    absolute_jump(craft_relay,(void*)&craft_wild_game);
    absolute_jump(stock_relay,(void*)&carcasses_in_camp);
    if(!hunt_relative(copy+(0x4ddf17c-HUNTING_RVA)+1,craft_relay,copy+(0x4ddf181-HUNTING_RVA)) ||
       !hunt_relative(copy+(0x4ddf1c5-HUNTING_RVA)+1,stock_relay,copy+(0x4ddf1ca-HUNTING_RVA)))return 0;

    /* Accept dead deer (role 8) as well as hares (role 20). */
    unsigned char *role=copy+4160;
    static const unsigned char role_test[]={0x80,0xbb,0xb1,0x0a,0,0,8,0x0f,0x84,0,0,0,0,
                                          0x80,0xbb,0xb1,0x0a,0,0,20,0x0f,0x84,0,0,0,0,0xe9,0,0,0,0};
    memcpy(role,role_test,sizeof(role_test));
    if(!hunt_relative(role+9,copy+(0x4ddf23d-HUNTING_RVA),role+13) ||
       !hunt_relative(role+22,copy+(0x4ddf23d-HUNTING_RVA),role+26) ||
       !hunt_relative(role+27,copy+(0x4ddf2fc-HUNTING_RVA),role+31) ||
       !hunt_branch(copy+(0x4ddf230-HUNTING_RVA),role))return 0;

    /* Search both native node types. All remaining target scoring is unchanged. */
    unsigned char *node=copy+4208;
    static const unsigned char node_test[]={0x83,0xbb,0xa8,2,0,0,4,0x0f,0x84,0,0,0,0,
                                          0x83,0xbb,0xa8,2,0,0,10,0x0f,0x84,0,0,0,0,0xe9,0,0,0,0};
    memcpy(node,node_test,sizeof(node_test));
    if(!hunt_relative(node+9,copy+(0x4ddf617-HUNTING_RVA),node+13) ||
       !hunt_relative(node+22,copy+(0x4ddf617-HUNTING_RVA),node+26) ||
       !hunt_relative(node+27,copy+(0x4ddf7b1-HUNTING_RVA),node+31) ||
       !hunt_branch(copy+(0x4ddf60a-HUNTING_RVA),node))return 0;

    /* Transport the correct carcass: stag=2, hare=44. RSI is the chosen animal. */
    unsigned char *carcass=copy+4256;
    static const unsigned char carcass_type[]={0xc7,0x45,0x20,44,0,0,0,
        0x80,0xbe,0xb1,0x0a,0,0,8,0x75,7,0xc7,0x45,0x20,2,0,0,0,0xe9,0,0,0,0};
    memcpy(carcass,carcass_type,sizeof(carcass_type));
    if(!hunt_relative(carcass+24,copy+(0x4ddf3c2-HUNTING_RVA),carcass+28) ||
       !hunt_branch(copy+(0x4ddf3bb-HUNTING_RVA),carcass))return 0;

    /* Preserve stack walking, including the original chained unwind records. */
    const unsigned unwind_offset=4352;
    memcpy(copy+unwind_offset,hunting_unwind,sizeof(hunting_unwind));
    for(size_t i=0;i<sizeof(hunting_chains)/sizeof(hunting_chains[0]);++i) {
        unsigned *chain=(unsigned*)(copy+unwind_offset+hunting_chains[i]);
        chain[2]+=unwind_offset;
    }
    for(size_t i=0;i<sizeof(hunting_ranges)/sizeof(hunting_ranges[0]);++i) {
        hunting_functions[i]=hunting_ranges[i];hunting_functions[i].UnwindData+=unwind_offset;
    }
    DWORD previous;
    if(!VirtualProtect(copy,8192,PAGE_EXECUTE_READ,&previous))return 0;
    FlushInstructionCache(GetCurrentProcess(),copy,8192);
    if(!RtlAddFunctionTable(hunting_functions,(DWORD)(sizeof(hunting_functions)/sizeof(hunting_functions[0])),
                           (DWORD64)(uintptr_t)copy))return 0;
    /* Retained with the pinned DLL, even after the entry detour is restored. */
    hunting_code=copy;return 1;
}
