/* QA-only kernel-policy canary. Never linked into the application. */
#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

static int probe(int family, int type) {
    int fd=socket(family,type,0);
    if(fd<0) return errno;
    fcntl(fd,F_SETFL,O_NONBLOCK);
    struct sockaddr_storage storage={0};
    socklen_t size;
    if(family==AF_INET) {
        struct sockaddr_in *p=(void *)&storage;
        p->sin_len=sizeof(*p); p->sin_family=AF_INET; p->sin_port=htons(443);
        inet_pton(AF_INET,"127.0.0.1",&p->sin_addr); size=sizeof(*p);
    } else {
        struct sockaddr_in6 *p=(void *)&storage;
        p->sin6_len=sizeof(*p); p->sin6_family=AF_INET6; p->sin6_port=htons(443);
        inet_pton(AF_INET6,"::1",&p->sin6_addr); size=sizeof(*p);
    }
    int rc=type==SOCK_STREAM ? connect(fd,(void *)&storage,size)
        : (int)sendto(fd,"QA",2,0,(void *)&storage,size);
    int result=rc>=0 ? 0 : errno;
    close(fd); return result;
}
int main(int argc,char **argv) {
    if(argc!=2) return 2;
    FILE *f=fopen(argv[1],"rb"); if(!f) return 3;
    fseek(f,0,SEEK_END); long size=ftell(f); rewind(f);
    if(size<=0) return 4;
    void *data=malloc((size_t)size);
    if(fread(data,1,(size_t)size,f)!=(size_t)size) return 5;
    fclose(f);
    int (*apply)(const char *,int,void *)=dlsym(RTLD_DEFAULT,"__sandbox_ms");
    if(!apply) return 6;
    uint64_t arguments[]={(uintptr_t)data,(uint64_t)size,0,0};
    int applied=apply("Sandbox",0,arguments);
    printf("sandbox_apply=%d errno=%d\n",applied,errno);
    if(applied) return 7;
    int failed=0;
    int families[]={AF_INET,AF_INET6}; int types[]={SOCK_STREAM,SOCK_DGRAM};
    for(int i=0;i<2;i++) for(int j=0;j<2;j++) {
        int result=probe(families[i],types[j]);
        printf("%s %s: errno=%d (%s)\n",i ? "IPv6" : "IPv4",j ? "UDP" : "TCP",result,(result==EPERM||result==EACCES) ? "DENIED" : "UNCONFIRMED");
        if(result!=EPERM&&result!=EACCES) failed=1;
    }
    free(data); return failed;
}
