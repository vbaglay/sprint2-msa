#!/bin/bash
echo "Testing Canary Release and Fallback via Istio Ingress"

# Start ingress gateway port-forward
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 --address=0.0.0.0 > /dev/null 2>&1 &
INGRESS_PID=$!
sleep 3

echo
echo "Test 1: Canary 90/10 distribution (100 requests)"
v1_count=0
v2_count=0

for i in {1..100}; do
    response=$(curl -s -H "Host: booking.local" http://localhost:8080/ping)
    
    if [[ "$response" == *"version: v1"* ]]; then
        ((v1_count++))
        echo -n "v1 "
    elif [[ "$response" == *"version: v2"* ]]; then
        ((v2_count++))
        echo -n "v2 "
    else
        echo -n "err "
    fi
    
    if (( i % 20 == 0 )); then
        echo " [$i]"
    fi
    sleep 0.05
done

echo
echo "Canary Results: v1=$v1_count ($((v1_count * 100 / 100))%), v2=$v2_count ($((v2_count * 100 / 100))%)"

echo
echo "Test 2: Header-based routing (20 requests each)"
echo
echo "x-version: v2 ->"
header_v2_count=0
for i in {1..20}; do
    response=$(curl -s -H "Host: booking.local" -H "x-version: v2" http://localhost:8080/ping)
    if [[ "$response" == *"version: v2"* ]]; then
        ((header_v2_count++))
        echo -n "ok "
    else
        echo -n "fail "
    fi
    
    if (( i % 10 == 0 )); then
        echo " [$i]"
    fi
    sleep 0.05
done

echo
echo
echo "X-Feature-Enabled: true ->"
feature_v2_count=0
for i in {1..20}; do
    response=$(curl -s -H "Host: booking.local" -H "X-Feature-Enabled: true" http://localhost:8080/ping)
    if [[ "$response" == *"version: v2"* ]]; then
        ((feature_v2_count++))
        echo -n "ok "
    else
        echo -n "fail "
    fi
    
    if (( i % 10 == 0 )); then
        echo " [$i]"
    fi
    sleep 0.05
done

echo
echo
echo "/feature endpoint ->"
feature_endpoint_ok=0
for i in {1..20}; do
    response=$(curl -s -H "Host: booking.local" -H "X-Feature-Enabled: true" http://localhost:8080/feature)
    if [[ "$response" == *"Feature X is enabled"* ]]; then
        ((feature_endpoint_ok++))
        echo -n "ok "
    else
        echo -n "fail "
    fi
    
    if (( i % 10 == 0 )); then
        echo " [$i]"
    fi
    sleep 0.05
done

echo
echo
echo "Header Routing Results:"
echo "x-version:v2    = $header_v2_count/20"
echo "feature-flag    = $feature_v2_count/20" 
echo "/feature        = $feature_endpoint_ok/20"

echo
echo "Test 3: Fallback when v1 is down (50 requests)"
echo "Scaling down v1 deployment..."
kubectl scale deployment booking-service-v1 --replicas=0
sleep 10

v2_count_fallback=0
for i in {1..50}; do
    response=$(curl -s -H "Host: booking.local" http://localhost:8080/ping)
    if [[ "$response" == *"version: v2"* ]]; then
        ((v2_count_fallback++))
        echo -n "v2 "
    else
        echo -n "err "
    fi
    
    if (( i % 25 == 0 )); then
        echo " [$i]"
    fi
    sleep 0.05
done

echo
echo "Fallback Results: v2=$v2_count_fallback/50 requests"

echo
echo "Test 4: Restoration after v1 is back (50 requests)"
echo "Scaling up v1 deployment..."
kubectl scale deployment booking-service-v1 --replicas=1
sleep 10

v1_count_restore=0
v2_count_restore=0
for i in {1..50}; do
    response=$(curl -s -H "Host: booking.local" http://localhost:8080/ping)
    if [[ "$response" == *"version: v1"* ]]; then
        ((v1_count_restore++))
        echo -n "v1 "
    elif [[ "$response" == *"version: v2"* ]]; then
        ((v2_count_restore++))
        echo -n "v2 "
    else
        echo -n "err "
    fi
    
    if (( i % 25 == 0 )); then
        echo " [$i]"
    fi
    sleep 0.05
done

echo
echo "Restoration Results: v1=$v1_count_restore ($((v1_count_restore * 100 / 50))%), v2=$v2_count_restore ($((v2_count_restore * 100 / 50))%)"

echo
echo "FINAL SUMMARY:"
echo "Canary 90/10:      v1=$((v1_count * 100 / 100))% v2=$((v2_count * 100 / 100))%"
echo "Header routing:    x-version:v2=$header_v2_count/20"
echo "Feature flags:     X-Feature-Enabled=$feature_v2_count/20"
echo "Feature endpoint:  /feature=$feature_endpoint_ok/20" 
echo "Fallback:          v2=$v2_count_fallback/50 when v1 down"
echo "Restoration:       v1=$((v1_count_restore * 100 / 50))% after restoration"

# Cleanup
kill $INGRESS_PID 2>/dev/null
echo "Testing completed!"