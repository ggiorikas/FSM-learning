
package org.example.learnlib;

import java.util.*;
import java.io.*;
import java.nio.file.*;

import org.json.*;

import de.learnlib.algorithms.rpni.BlueFringeRPNIMealy;
import de.learnlib.api.algorithm.PassiveLearningAlgorithm.PassiveMealyLearner;
import de.learnlib.api.query.DefaultQuery;
import net.automatalib.automata.transducers.MealyMachine;
import net.automatalib.visualization.Visualization;
import net.automatalib.visualization.DefaultVisualizationHelper;
import net.automatalib.words.Alphabet;
import net.automatalib.words.Word;
import net.automatalib.words.*;
import net.automatalib.words.impl.Alphabets;
import net.automatalib.automata.transducers.impl.compact.CompactMealyTransition;





public final class ExampleMealy {


    public static void main(String[] args) {


        
        Collection<DefaultQuery<String, Word<String>>> sample;

        System.out.println("loading sample from file...");

        
        long pstart = System.nanoTime();
        
        sample = loadMealySample("path/to/train30ff.txt");
        
        long pstop = System.nanoTime();
        
        System.out.println("time taken to parse input: " + Double.valueOf((pstop - pstart) / 1000000.).toString());


        //final Alphabet<String> alphabet = Alphabets.fromList(Arrays.asList("alpha", "beta"));

        long astart = System.nanoTime();
        
        System.out.println("extracting alphabets from sample...");

        ArrayList<Alphabet<String>> alphabets = sample2alphabets(sample);
        Alphabet<String> alphaIn = alphabets.get(0);
        Alphabet<String> alphaOut = alphabets.get(1);
        
        long astop = System.nanoTime();

        //Alphabet<String> alphaIn = Alphabets.fromList(Arrays.asList("0", "1"));
        //Alphabet<String> alphaOut = Alphabets.fromList(Arrays.asList("0", "1", "2", "3"));
        
        System.out.println("time taken to extract alphabets: " + Double.valueOf((astop - astart) / 1000000.).toString());


        System.out.println(alphaIn);
        System.out.println(alphaOut);


        System.out.println("learning...");

        long start = System.nanoTime();

        final PassiveMealyLearner<String, String> learner = new BlueFringeRPNIMealy<>(alphaIn);

        learner.addSamples(sample);

        final MealyMachine<Integer, String, CompactMealyTransition, String> model = 
            (MealyMachine<Integer, String, CompactMealyTransition, String>)learner.computeModel();

        long stop = System.nanoTime();

        System.out.println("done!");  

        System.out.println("elapsed time: " + Double.valueOf((stop - start) / 1000000.).toString());


        String mljs = mealy2json(model, alphaIn, alphaOut);

        //System.out.println(mljs);

        try {
            PrintWriter out = new PrintWriter("learned.json");

            out.println(mljs);

            out.close();

        } catch(Exception e) {

        }

        
    
    }


    private static Collection<DefaultQuery<String, Word<String>>> getMealySample() {
        return Arrays.asList(
            new DefaultQuery<>(Word.epsilon(), Word.fromList(Arrays.asList("alpha", "beta")), Word.fromList(Arrays.asList("1", "2"))),
            new DefaultQuery<>(Word.epsilon(), Word.fromList(Arrays.asList("beta", "alpha")), Word.fromList(Arrays.asList("3", "4"))),
            new DefaultQuery<>(Word.epsilon(), Word.fromList(Arrays.asList("alpha", "alpha")), Word.fromList(Arrays.asList("1", "4"))),
            new DefaultQuery<>(Word.epsilon(), Word.fromList(Arrays.asList("beta", "beta")), Word.fromList(Arrays.asList("3", "2")))
        );
    }



    private static ArrayList<Alphabet<String>> sample2alphabets(Collection<DefaultQuery<String, Word<String>>> sample) {

        HashSet<String> iletters = new HashSet<>();
        HashSet<String> oletters = new HashSet<>();

        sample.forEach(dq -> {

            Word<String> input = dq.getInput(), output = dq.getOutput();
            
            input.forEach(a -> { iletters.add(a); });
            output.forEach(a -> { oletters.add(a); });
        });

        return new ArrayList(Arrays.asList(Alphabets.fromList(new ArrayList(iletters)), Alphabets.fromList(new ArrayList(oletters))));
    }


    private static Collection<DefaultQuery<String, Word<String>>> loadMealySample(String path) {

        Collection<DefaultQuery<String, Word<String>>> ret = new ArrayList<>();

        try (BufferedReader r = Files.newBufferedReader(new File(path).toPath())) {

            String line;

            boolean first = true;

            while ((line = r.readLine()) != null) { 

                if (first) { first = false; continue; }
                
                String[] tokens = line.split(" "); 

                WordBuilder<String> iword = new WordBuilder<>();
                WordBuilder<String> oword = new WordBuilder<>();
                
                for (int i = 2; i < tokens.length; ++ i) {
                    String[] io = tokens[i].split("/");

                    iword.add(io[0]);
                    oword.add(io[1]);
                }

                ret.add(new DefaultQuery<>(Word.epsilon(), iword.toWord(), oword.toWord()));
            }
        } catch (Exception e) {
            System.out.println(e);
        }

        return ret;
    }


    private static String mealy2json(
        MealyMachine<Integer, String, CompactMealyTransition, String> mealy, 
        Alphabet<String> alphaIn, Alphabet<String> alphaOut) {

        JSONObject js = new JSONObject();

        //System.out.println(new JSONObject().put("Hello", "World").toString());
        
        //Visualization.visualize(mealy.transitionGraphView(alphaIn));

        js.put("input-alphabet", new JSONArray(alphaIn));
        js.put("output-alphabet", new JSONArray(alphaOut));

        Integer init = mealy.getInitialState();

        js.put("initial-state", init);

        Collection<Integer> states = mealy.getStates();

        js.put("states", new JSONArray(states));

        //System.out.println(init.getClass().getName());

        JSONObject transFun = new JSONObject();
        JSONObject outFun = new JSONObject();

        states.forEach(s -> {

            //System.out.println(s.getClass().getName());
            
            //System.out.print(s);

            if (s == init) {
                //System.out.print(" (init)");
            }

            //System.out.println();

            JSONObject jst = new JSONObject();
            JSONObject jso = new JSONObject();

            //*

            alphaIn.forEach(a -> {

                Collection<CompactMealyTransition> trans = mealy.getTransitions(s, a);

                trans.forEach(t -> {

                    //System.out.println(t.getClass().getName());
                    //System.out.println(t);

                    //System.out.print("  with " + a + " goes to ");
                    //System.out.println(t.getSuccId());
                    
                    //System.out.print("  and outputs ");
                    //System.out.println(t.getOutput());

                    jst.put(a, t.getSuccId());
                    jso.put(a, t.getOutput());

                });
            });
            //*/

            transFun.put(s.toString(), jst);
            outFun.put(s.toString(), jso);
        });

        js.put("output-function", outFun);
        js.put("transition-function", transFun);

        return js.toString(4);

    }


}


