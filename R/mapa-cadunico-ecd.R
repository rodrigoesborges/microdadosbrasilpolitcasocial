#Mapas de situação da cadunicoecdção da primeira infância nos municípios do ES



#Pacotes necessários
require(tidyverse)
devtools::install_github("rpradosiqueira/brazilmaps")
require(dplyr)
require(brazilmaps)
require(plotly)
library(sf)

#variaveis de ambiente e prefixadas
dtsav <- "~/RLocalData/ecd-indicadores"

#Anos da análise
anosel <- seq(2012,2017,1)

#Primeira tentativa de mapa: dados de 
cadunicoecd <- readRDS(paste0("data/2012-2017-indicadores-cadunico-ES.rds"))
cadunicoecd <- cadunicoecd[,c(1,6,10,2:5,7:9)] %>% pivot_longer(cols = 4:10, names_to = "indicador")
#cadunicoecd$cod_mun <- as.numeric(levels(cadunicoecd$cod_mun))[cadunicoecd$cod_mun]

cadunicoecd$cod_mun <- as.numeric(cadunicoecd$cod_mun)
#pegar o mapa e juntar aos dados de cadunicoecdção

#Mapa municípios ES
mapa_m_es <- get_brmap("City", geo.filter = list(State = 32)) 


#Indicadores do ES
cadunicoecd <- cadunicoecd %>% filter(grepl("^32",cod_mun))


#Nome dos indicadores
n_ind_as <- data.frame(indicador = unique(cadunicoecd$indicador))



n_ind_as$leg <- c("Crianças CadUnico n. beneficiárias PBF",
                  "Crianças beneficiárias PBF",
                  "desv.pad. n. pbf",
                  "desv.pad. ben. pbf",
                  "pop 0 a 6",
                  "proporção total inscritas CadUnico / pop 0 a 6",
                  "proporção de beneficiárias pbf / pop 0 a 6")

            
                  
                  
n_ind_as$tit <- c("Primeira Infância - Assistência",
                      "Primeira Infância - Assistência",
                      "Primeira Infância - Assistência",
                      "Primeira Infância - Assistência",
                      "Primeira Infância - Assistência",
                      "Primeira Infância - Assistência",
                      "Primeira Infância - Assistência")

mapa_m_es$cod_mun <- as.numeric(substr(mapa_m_es$City,0,6))

mapas_as_ecd <- function(ano = anosel,uf = "ES", ci = n_ind_as) {


# i - > removidos indicadores de desvio padrão, removido provisoriamente indicador n_pbf
for (i in c(2,5,6,7)) {                         
tx <- cadunicoecd %>% filter(indicador == ci[i,1])

#Estratificar as coberturas para obter menos cores
if (max(tx$value, na.rm = T)<= 1) {
tx$taxa <- cut(tx$value,
                      c(0, 0.2, 0.4, 0.6, 0.8, 1.0))
}
else {
  m <- max(tx$value, na.rm = TRUE)
  tx$taxa <- cut(tx$value,
                 c(0,round(m/5, digits = 0),
                   round(m*2/5, digits = 0),
                   round(m*3/5, digits = 0),
                   round(m*4/5, digits = 0),
                   m))
}

#Compatibiliza bases para filtragem por código de município
mapa_m_es$cod_mun <- as.numeric(substr(mapa_m_es$City,0,6))
txs <- tx

n_part1 <- paste0("mapa_",ci[i,1])
print(n_part1)
#problema kernels
#Sys.setenv("OPENBLAS_CORETYPE"="Haswell")
for (j in 1:length(ano)) {
  nome <- paste0(n_part1,"_",anosel[j])
  tx <- txs[txs$ano == anosel[j],]
  mapa <- mapa_m_es %>%
    left_join(tx) %>%
    ggplot() +
    geom_sf(aes(fill = taxa),
            #ajusta tamanho das linhas
            colour = "black", size = 0.1)+
  #   #muda escala de core
     scale_fill_viridis_d(option = 2, begin = 1, end = 0) +
    theme(panel.grid =
            element_line(colour = "transparent"),
          panel.background = element_blank(),
          axis.text = element_blank(),
          axis.ticks = element_blank())+
    labs(title = paste0(ci$tit[i]," - ",uf," - ",anosel[j]),
         fill = ci$leg[i])
  assign(nome, mapa) 
  print(get(nome))
  ggsave(filename = paste0(dtsav,"/",nome,".png"), dpi = "retina", scale = 1.2)
}
}
  }

mapas_as_ecd()


#Para ver interativamente - problema com fonte de texto
#ggplotly(`mapa tx_creche 2012`) 

#Para plotly
tx$texto <- with(tx, paste(`Município`," - ", `valor`))


get_brmap("City", geo.filter = list(State = 32)) %>%
  left_join(tx_creche, c("nome" = "local")) %>%
  ggplot() +
  geom_sf(aes(fill = tx_creche$Tx.de.Cobertura.Efetiva...Creche),
          #ajusta tamanho das linhas
          colour = "black", size = 0.1) +
  #muda escala de cores
  scale_fill_viridis_c(option = 2, direction = -1) +
  theme(panel.grid = 
          element_line(colour = "transparent"),
        panel.background = element_blank(),
        axis.text = element_blank(),
        axis.ticks = element_blank())+
  labs(title = "Cobertura de Creche no Espirito Santo - 2017",
       fill = "Taxa de Cobertura Efetiva de Creche")


##################AGREGADO POR MESORREGIÕES - MÉDIA PONDERADA
cadunicoecd$reg_micro <- floor(cadunicoecd$cod_mun/10000)*1000+as.numeric(cadunicoecd$`Microrregião Geográfica`)


cadunico_mr <- cadunicoecd %>% group_by(reg_micro,ano,indicador) %>% 
  summarise(valor = weighted.mean(value,pop0a6, na.rm = T), 
            mesorregiao = max(Nome_Microrregião), 
            cod_mr = max(reg_micro))

cadunico_mr_br <- cadunicoecd %>% group_by(ano, indicador) %>% 
  summarise(valor = weighted.mean(value, pop0a6, na.rm = T),
            mesorregiao = "Brasil",
            cod_mr = 0)
cadunicoecd$uf <- floor(cadunicoecd$cod_mun/10000)

cadunicoecd <- na.omit(cadunicoecd)

cadunico_mr_uf <- cadunicoecd %>% group_by(ano, indicador, uf) %>% 
  summarise(valor = weighted.mean(value, pop0a6, na.rm = T),mesorregiao = as.character(max(uf)),
            cod_mr = max(uf)*1000)

cadunico_mr_uf <- na.omit(cadunico_mr_uf)
cadunico_mr <- rbind(cadunico_mr, cadunico_mr_uf,cadunico_mr_br)

cadunico_mr <- cadunico_mr %>% filter(grepl("^32|^0",cod_mr)) 

cadunico_mr[cadunico_mr$cod_mr == 0,]$mesorregiao <- "Brasil"

## Para o Espírito Santo apenas
cadunico_mr_es <- cadunico_mr[floor(cadunico_mr$cod_mr/1000) == 32 | cadunico_mr$cod_mr == 0,]

### apenas Brasil, Espírito Santo e 5 cidades fixas

regsel <- c(32013,32010,32011,32002,32009,32000,0)

#Montanha - 32004P
#Vitória - 32009
#Itapemirim - 32013
#Guarapari - 32010
# Alegre - 32011
# Nova Venécia - 3202

cadunico_mr_es <- cadunico_mr_es[cadunico_mr_es$cod_mr %in% regsel,]

cadunico_mr_es[cadunico_mr_es$mesorregiao == 32,]$mesorregiao <- "Espírito Santo"

graficos_cadunico_mr <- lapply(1:length(unique(cadunicoecd$indicador)), function(x) {
  ggplot(cadunico_mr_es[cadunico_mr_es$indicador == unique(cadunico_mr_es$indicador)[x],],
         aes(x = ano, y = valor, colour = mesorregiao))+
    #scale_y_continuous(labels = scales::percent_format(accuracy = 1))+
    geom_line()+
    theme_classic()+
    labs(title = cadunico_mr_es$indicador[x])
}
)

lapply(1:length(unique(cadunicoecd$indicador)),function(x) ggplotly(graficos_cadunico_mr[[x]]))  


lapply(1:length(unique(cadunicoecd$indicador)),function(x) {
  ggsave(filename = paste0(dtsav,"/es-microrregiao-",unique(cadunico_mr_es$indicador)[x],".png"), plot = graficos_cadunico_mr[[x]],width = 180 , height = 90, units = "mm")
})



