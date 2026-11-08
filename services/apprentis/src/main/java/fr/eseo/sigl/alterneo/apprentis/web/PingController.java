package fr.eseo.sigl.alterneo.apprentis.web;

import java.time.Instant;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoint témoin du squelette.
 *
 * Il répond sur le préfixe /api/apprentis, celui que la passerelle
 * routera vers ce service. Il permet de vérifier de bout en bout que le
 * conteneur est joignable, en local comme sur Azure.
 *
 * À supprimer quand les vrais endpoints du service seront en place.
 */
@RestController
@RequestMapping("/api/apprentis")
public class PingController {

    @Value("${spring.application.name}")
    private String service;

    @GetMapping("/ping")
    public Map<String, String> ping() {
        return Map.of(
                "service", service,
                "statut", "en ligne",
                "horodatage", Instant.now().toString()
        );
    }
}
