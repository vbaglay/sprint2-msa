Для меня многое новое тут, поэтому я следовал инструкции и все получилось.
Дольше настраивал среду для сборки всего.

1. создал образ booking service
2. создал Helms
3. создал скрипт CI/CD пайплайн

Build
Собирает Docker образ из ./booking-service/Dockerfile
Тег: booking-service:latest

Test
Запускает контейнер на порту 8080
Проверяет health-check через /ping
Останавливает контейнер после теста

Deploy 
minikube image load - загружает образ в Minikube
helm upgrade --install - разворачивает в Kubernetes через Helm
image.tag=latest - использует свежий образ
image.pullPolicy=Never - не скачивать из registry (использует локальный)

Helm прикольная штука:

 - Вместо hardcode:
replicas: {{ .Values.replicaCount }}

 - Управление конфигурацией, разные окружения одним чартом:
helm install --set replicaCount=3 --set image.tag=staging

 - Версионирование: helm rollback booking-service 1

