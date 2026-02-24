app {
  url = "https://github.com/luceracloud/alerta-release"
}

pack {
  name        = "alerta_release"
  description = "Alerta Release Package"
  version     = "v1.0.1"
}

dependency "lucera_alerta" {
  alias  = "lucera_alerta"
  source = "git::https://github.com/kcalderwood1/lucera-alerta.git//packs/lucera_alerta?ref=v0.1.3&depth=1"
}
