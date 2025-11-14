Не все смог создать по инструкции, было много проблем снова с конфигурацией среда и настройкой распределения трафика. Поэтому пошел немного своим путем. всегда 

### 1. **values-v1.yaml**
- Конфигурация Helm для версии v1
- 3 реплики, версия "v1", фича X отключена
- Настройки ресурсов и health checks

### 2. **values-v2.yaml** 
- Конфигурация Helm для версии v2 с новыми функциями
- 1 реплика, версия "v2", фича X включена
- Дополнительные настройки feature flags и новый endpoint `/feature`

### 3. **destinationrule.yaml**
- DestinationRule для booking-service
- Circuit breaking: maxConnections=100, pendingRequests=50
- Outlier detection: автоматическое исключение неисправных инстансов
- Определены subsets v1 и v2 по labels

### 4. **virtualservice.yaml**
- VirtualService для маршрутизации трафика
- Header-based routing по `x-version: v2`
- Canary release: 90% трафика на v1, 10% на v2
- Применяется к booking-gateway

### 5. **envoyfilter-feature-flag.yaml**
- EnvoyFilter для feature flag маршрутизации
- Добавляет Lua-скрипт в ingress gateway
- При заголовке `X-Feature-Enabled: true` направляет на v2
- Применяется к порту 8080 ingress gateway

### 6. **test-canary.sh**
- Автоматический тест всех сценариев развертывания
- Проверяет canary distribution, header routing, feature flags
- Тестирует fallback при отказе v1 и восстановление
- Выводит детальную статистику по всем тестам

## Порядок развертывания:
1. Развернуть v1 и v2 с Helm values
2. Применить DestinationRule для определения версий
3. Настроить VirtualService для маршрутизации
4. Добавить EnvoyFilter для feature flags
5. Запустить тестовый скрипт для проверки