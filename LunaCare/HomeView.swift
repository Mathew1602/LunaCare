//
//  HomeView.swift
//  LunaCare
//
//  Created by Xiaoya Zou on 2025-10-08.
//  Updated by Mathew on 2025-10-09

import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            HomeContentView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .tint(Color(.systemIndigo))
    }
}

struct HomeContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Hi Emma,")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("how are you feeling today?")
                        .foregroundColor(.gray)
                    
                    // Log Mood Button
                    Button {
                        // Dummy log mood action
                    } label: {
                        HStack {
                            Text("Log Mood")
                            Image(systemName: "smiley")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemIndigo).opacity(0.2))
                        .foregroundColor(Color(.systemIndigo))
                        .cornerRadius(10)
                    }
                    .padding(.top, 10)
                    
                    // Key Health Metrics
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Key Health Metrics")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            MetricCard(icon: "moon", value: "7 hrs", label: "Sleep")
                            MetricCard(icon: "waveform.path.ecg", value: "3,231 cal", label: "Activity")
                            MetricCard(icon: "heart", value: "71", label: "Resting HR")
                        }
                    }
                    .padding(.top, 10)
                    
                    // Alerts
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alerts")
                            .font(.headline)
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(Color(.systemIndigo))
                            Text("Your sleep has been low for 2 nights")
                            Spacer()
                            Text("View Tips")
                                .foregroundColor(Color(.systemIndigo))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Quick Access
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Access")
                            .font(.headline)
                        HStack(spacing: 20) {
                            QuickAccessButton(icon: "doc.text.magnifyingglass", title: "Reports")
                            QuickAccessButton(icon: "chart.bar.xaxis", title: "Insights")
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trackers")
                            .font(.headline)
                            .padding(.top, 20)
                        
                        NavigationLink {
                            MoodTrackingView()
                        } label: {
                            HStack {
                                Label("Mood Tracking", systemImage: "face.smiling")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        NavigationLink {
                            SymptomsTrackingView()
                        } label: {
                            HStack {
                                Label("Symptoms Tracking", systemImage: "cross.case")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        Text("Calendar")
                            .font(.headline)
                            .padding(.top, 8)

                        // Mood Calendar card
                        NavigationLink {
                            MoodCalendarView()
                        } label: {
                            HStack {
                                Label("Mood Calendar", systemImage: "calendar")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        NavigationLink {
                            SymptomCalendarView()
                        } label: {
                            HStack {
                                Label("Symptom Calendar", systemImage: "calendar")
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                    }
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("Home")
        }
    }
}





#Preview {
    HomeView()
}

