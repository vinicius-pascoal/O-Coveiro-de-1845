# Configurações de build do projeto (incluídas pelo editor e pelo export).

# A cena World gerada em C++ é grande e estoura a pilha padrão de 1 MB do Windows
# ao carregar (0xC00000FD). Uma pilha de 32 MB resolve.
if(MSVC)
    target_link_options(${DORIAX_TARGET} PRIVATE /STACK:33554432)
elseif(MINGW)
    target_link_options(${DORIAX_TARGET} PRIVATE -Wl,--stack,33554432)
endif()
