**A Bench.sh Script By Teddysun - Modify by DigneZ**
```
wget -qO- bench.gig.ovh | bash
```

**Тестирование скорости к РФ провайдерам через iperf3**
```
apt install iperf3
bash <(wget -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh)
```

**IP region проверка геолокиции ip адресса VPS**
```
bash <(wget -qO - https://github.com/vernette/ipregion/raw/master/ipregion.sh)
```

**Yabs бенчмарк, информация о системе и првоерка скорости к зарубежным провайдерам**
```
curl -sL yabs.sh | bash -s -- -4
```

**Параметры сервера и проверка скорости к зарубежным провайдерам (Старая версия через SpeedTest)**
```
wget -qO- bench.sh | bash
```

 **Проверка IP сервера на блокировки зарубежными сервисами**
```
bash <(curl -Ls IP.Check.Place) -l en
```

**Censorcheck проверяет доступность популярных сайтов**
```
wget https://github.com/vernette/censorcheck/raw/master/censorcheck.sh && chmod +x censorcheck.sh && ./censorcheck.sh
```

**Тестирование региональных ограничений для потоковых платформ и игр**
```
bash <(curl -L -s https://bench.gig.ovh/multi_check_ru.sh)
```

**Проверка блокировки аудио в Instagram:**
```
bash <(curl -L -s https://bench.openode.xyz/checker_inst.sh)
```

**Тест на процессор, можно понять примерно какой процент cpu выделили**
```
apt install sysbench
sysbench cpu run --threads=1
```

**Сайт для анализа маршрутов BGP в Интернете**
```
https://bgp.tools
```
