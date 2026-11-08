package fr.eseo.sigl.alterneo.apprentis;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Deux tests minimaux, mais réels : ils doivent passer dans la chaîne
 * d'intégration continue pour qu'une pull request soit fusionnable.
 */
@SpringBootTest
@AutoConfigureMockMvc
class ApprentisApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("le contexte Spring démarre")
    void contextLoads() {
        // Échoue si une configuration est cassée.
    }

    @Test
    @DisplayName("GET /api/apprentis/ping répond que le service est en ligne")
    void pingRepondEnLigne() throws Exception {
        mockMvc.perform(get("/api/apprentis/ping"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("apprentis"))
                .andExpect(jsonPath("$.statut").value("en ligne"));
    }
}
