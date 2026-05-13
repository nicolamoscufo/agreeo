#!/bin/bash
set -e

# Aspetta che Neo4j sia pronto
echo "Attesa che Neo4j sia disponibile..."
for i in {1..30}; do
  if cypher-shell -u neo4j -p password123 "RETURN 1" > /dev/null 2>&1; then
    echo "Neo4j è pronto!"
    break
  fi
  echo "Tentativo $i/30 - Neo4j non ancora pronto, attesa 2 secondi..."
  sleep 2
done

# Controlla se i dati sono già stati importati
echo "Verifica se i dati sono già importati..."
EXISTING_NODES=$(cypher-shell -u neo4j -p password123 "MATCH (n) RETURN count(n) as count;" 2>/dev/null | tail -1)

if [ "$EXISTING_NODES" -gt 0 ]; then
  echo "Database già inizializzato con $EXISTING_NODES nodi. Skip import."
else
  echo "Database vuoto. Inizio import dei dati MovieLens..."
  cypher-shell -u neo4j -p password123 -f /var/lib/neo4j/import/import_movielens.cypher
  echo "Import completato!"
fi

echo "Inizializzazione Neo4j terminata."
