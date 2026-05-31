package pwr.zbd.projekt;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Punkt wejścia Spring Boot — skanuje pakiety pod {@code pwr.zbd.projekt} (kontrolery, repozytoria, {@code DatabaseInit}).
 */
@SpringBootApplication
public class ProjektApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProjektApplication.class, args);
    }

}
