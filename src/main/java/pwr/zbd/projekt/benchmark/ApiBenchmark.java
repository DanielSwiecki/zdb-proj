package pwr.zbd.projekt.benchmark;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.*;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Prosty benchmark HTTP (pojedynczy poziom obciazenia).
 * <p>
 * Do pelnego testu granicy systemu (wykres P95 i skutecznosc vs uzytkownicy)
 * uzyj: {@code .\tools\run_benchmark.ps1} z profilem Spring {@code benchmark}.
 * <p>
 * Run: java pwr.zbd.projekt.benchmark.ApiBenchmark &lt;baseUrl&gt; &lt;operation&gt; &lt;threads&gt; &lt;requests&gt;
 * Operations: HEALTH, ENROLL (unikaj GET_ALL przy 10k grup!)
 */
public class ApiBenchmark {

    private static final String API_BASE = "/api/course-groups";
    private String baseUrl;
    private String operation;
    private int threads;
    private int requestsPerThread;

    private List<Long> responseTimes = Collections.synchronizedList(new ArrayList<>());
    private int successCount = 0;
    private int failureCount = 0;
    private Object lockCount = new Object();

    public static void main(String[] args) {
        if (args.length < 4) {
            System.out.println("Usage: java ApiBenchmark <baseUrl> <operation> <threads> <requests>");
            System.out.println("Operations: HEALTH, ENROLL, UNENROLL, GET_BY_ID, GET_ALL (GET_ALL nie dla duzej bazy!)");
            System.out.println("Example: java ApiBenchmark http://localhost:8081 GET_ALL 10 1000");
            System.exit(1);
        }

        String baseUrl = args[0];
        String operation = args[1];
        int threads = Integer.parseInt(args[2]);
        int requests = Integer.parseInt(args[3]);

        ApiBenchmark benchmark = new ApiBenchmark(baseUrl, operation, threads, requests);
        benchmark.run();
    }

    public ApiBenchmark(String baseUrl, String operation, int threads, int requests) {
        this.baseUrl = baseUrl;
        this.operation = operation.toUpperCase();
        this.threads = threads;
        this.requestsPerThread = requests;
    }

    public void run() {
        System.out.println("🚀 Starting API Benchmark");
        System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        System.out.println("Base URL: " + baseUrl);
        System.out.println("Operation: " + operation);
        System.out.println("Threads: " + threads);
        System.out.println("Requests per thread: " + requestsPerThread);
        System.out.println("Total requests: " + (threads * requestsPerThread));
        System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

        ExecutorService executor = Executors.newFixedThreadPool(threads);
        CountDownLatch latch = new CountDownLatch(threads);
        long startTime = System.currentTimeMillis();

        for (int i = 0; i < threads; i++) {
            executor.execute(() -> {
                for (int j = 0; j < requestsPerThread; j++) {
                    try {
                        executeRequest(operation);
                    } catch (Exception e) {
                        synchronized (lockCount) {
                            failureCount++;
                        }
                    }
                }
                latch.countDown();
            });
        }

        try {
            latch.await();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        executor.shutdown();
        long endTime = System.currentTimeMillis();
        long totalTime = endTime - startTime;

        printResults(totalTime);
    }

    private void executeRequest(String operation) throws Exception {
        long startTime = System.nanoTime();

        try {
            switch (operation) {
                case "HEALTH":
                    health();
                    break;
                case "GET_ALL":
                    getAll();
                    break;
                case "GET_BY_ID":
                    getById();
                    break;
                case "ENROLL":
                    enroll();
                    break;
                case "UNENROLL":
                    unenroll();
                    break;
                case "MIXED":
                    Random rand = new Random();
                    int choice = rand.nextInt(4);
                    switch (choice) {
                        case 0: getAll(); break;
                        case 1: getById(); break;
                        case 2: enroll(); break;
                        case 3: unenroll(); break;
                    }
                    break;
            }

            long endTime = System.nanoTime();
            long responseTime = (endTime - startTime) / 1_000_000; // Convert to ms
            responseTimes.add(responseTime);

            synchronized (lockCount) {
                successCount++;
            }
        } catch (Exception e) {
            synchronized (lockCount) {
                failureCount++;
            }
            throw e;
        }
    }

    private void health() throws Exception {
        URL url = new URL(baseUrl + "/api/health");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(5000);
        int responseCode = conn.getResponseCode();
        if (responseCode < 200 || responseCode >= 300) {
            throw new Exception("HTTP " + responseCode);
        }
        conn.disconnect();
    }

    private void getAll() throws Exception {
        URL url = new URL(baseUrl + API_BASE);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(5000);

        int responseCode = conn.getResponseCode();
        if (responseCode < 200 || responseCode >= 300) {
            throw new Exception("HTTP " + responseCode);
        }
        conn.disconnect();
    }

    private void getById() throws Exception {
        long groupId = new Random().nextInt(100) + 1; // Assuming max 100 groups
        URL url = new URL(baseUrl + API_BASE + "/" + groupId);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(5000);

        int responseCode = conn.getResponseCode();
        if (responseCode < 200 || responseCode >= 300) {
            throw new Exception("HTTP " + responseCode);
        }
        conn.disconnect();
    }

    private void enroll() throws Exception {
        long groupId = new Random().nextInt(100) + 1;
        URL url = new URL(baseUrl + API_BASE + "/" + groupId + "/enroll");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(5000);
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setDoOutput(true);

        // Generate random student UUID
        String studentId = UUID.randomUUID().toString();
        String jsonBody = "{\"studentId\":\"" + studentId + "\"}";

        try (OutputStream os = conn.getOutputStream()) {
            byte[] input = jsonBody.getBytes("utf-8");
            os.write(input, 0, input.length);
        }

        int responseCode = conn.getResponseCode();
        if (responseCode < 200 || responseCode >= 300) {
            throw new Exception("HTTP " + responseCode);
        }
        conn.disconnect();
    }

    private void unenroll() throws Exception {
        long groupId = new Random().nextInt(100) + 1;
        String studentId = UUID.randomUUID().toString();
        URL url = new URL(baseUrl + API_BASE + "/" + groupId + "/unenroll/" + studentId);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("DELETE");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(5000);

        int responseCode = conn.getResponseCode();
        // 204 No Content or 404 Not Found are acceptable
        conn.disconnect();
    }

    private void printResults(long totalTime) {
        System.out.println("\n✅ Benchmark Completed!");
        System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        System.out.println("Total Time: " + totalTime + " ms");
        System.out.println("Total Requests: " + (successCount + failureCount));
        System.out.println("Successful: " + successCount);
        System.out.println("Failed: " + failureCount);
        System.out.println("Success Rate: " + String.format("%.2f%%", (100.0 * successCount / (successCount + failureCount))));
        System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        if (responseTimes.size() > 0) {
            Collections.sort(responseTimes);
            long min = responseTimes.get(0);
            long max = responseTimes.get(responseTimes.size() - 1);
            long avg = responseTimes.stream().mapToLong(Long::longValue).sum() / responseTimes.size();
            long p50 = responseTimes.get((int) (responseTimes.size() * 0.50));
            long p95 = responseTimes.get((int) (responseTimes.size() * 0.95));
            long p99 = responseTimes.get((int) (responseTimes.size() * 0.99));

            System.out.println("\n📊 Response Time Statistics (ms):");
            System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            System.out.println("Min:  " + min);
            System.out.println("Max:  " + max);
            System.out.println("Avg:  " + avg);
            System.out.println("P50:  " + p50);
            System.out.println("P95:  " + p95);
            System.out.println("P99:  " + p99);
            System.out.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

            double throughput = (double) successCount / (totalTime / 1000.0);
            System.out.println("\n⚡ Throughput: " + String.format("%.2f", throughput) + " req/sec");
        }
    }
}
